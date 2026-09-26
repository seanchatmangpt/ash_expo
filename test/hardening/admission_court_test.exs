defmodule AshExpoHardening.AdmissionCourtTest do
  @moduledoc """
  Negative/adversarial court for the Spark verifier admission boundary
  (`AshExpo.Resource.Verifiers.ValidateProjection`) and the manifest/codegen
  projection built on top of it. Real Spark compilation, real files on disk;
  no test doubles.
  """
  use ExUnit.Case, async: true

  require Spark.Test

  alias AshExpoHardening.Support.{Disabled, Ordered, Plain, Reordered}

  describe "Spark verifier refuses illegal projections" do
    test "unknown action name" do
      error =
        Spark.Test.assert_dsl_error %Spark.Error.DslError{path: [:expo]} do
          defmodule Elixir.AshExpoHardening.UnknownAction do
            use Ash.Resource,
              domain: nil,
              extensions: [AshTypescript.Resource, AshExpo.Resource]

            typescript do
              type_name "UnknownAction"
            end

            attributes do
              uuid_primary_key :id
            end

            actions do
              defaults [:read]
            end

            expo do
              action :destroy_everything
            end
          end
        end

      assert error.message =~ "does not exist on AshExpoHardening.UnknownAction"
      assert error.message =~ ":destroy_everything"
    end

    test "private (public? false) action is an unauthorized projection" do
      error =
        Spark.Test.assert_dsl_error %Spark.Error.DslError{path: [:expo]} do
          defmodule Elixir.AshExpoHardening.PrivateAction do
            use Ash.Resource,
              domain: nil,
              extensions: [AshTypescript.Resource, AshExpo.Resource]

            typescript do
              type_name "PrivateAction"
            end

            attributes do
              uuid_primary_key :id
            end

            actions do
              read :read do
                primary? true
                public? false
              end
            end

            expo do
              action :read
            end
          end
        end

      assert error.message =~ "must be public? true"
    end

    test ":cacheable on a non-read action" do
      error =
        Spark.Test.assert_dsl_error %Spark.Error.DslError{path: [:expo]} do
          defmodule Elixir.AshExpoHardening.CacheableCreate do
            use Ash.Resource,
              domain: nil,
              extensions: [AshTypescript.Resource, AshExpo.Resource]

            typescript do
              type_name "CacheableCreate"
            end

            attributes do
              uuid_primary_key :id
            end

            actions do
              create :create do
                public? true
              end
            end

            expo do
              action :create, offline: :cacheable
            end
          end
        end

      assert error.message =~ ":cacheable is only valid for read actions"
      assert error.message =~ "is create"
    end

    test "duplicate projection names (duplicate delivery of one action)" do
      error =
        Spark.Test.assert_dsl_error %Spark.Error.DslError{path: [:expo]} do
          defmodule Elixir.AshExpoHardening.Duplicate do
            use Ash.Resource,
              domain: nil,
              extensions: [AshTypescript.Resource, AshExpo.Resource]

            typescript do
              type_name "Duplicate"
            end

            attributes do
              uuid_primary_key :id
            end

            actions do
              read :read do
                primary? true
                public? true
              end
            end

            expo do
              action :read, offline: :cacheable
              action :read, offline: :online_only
            end
          end
        end

      assert error.message =~ "must be unique"
      assert error.message =~ "[:read]"
    end

    test "AshExpo without AshTypescript is refused (no second API model)" do
      error =
        Spark.Test.assert_dsl_error %Spark.Error.DslError{path: [:expo]} do
          defmodule Elixir.AshExpoHardening.NoTypescript do
            use Ash.Resource,
              domain: nil,
              extensions: [AshExpo.Resource]

            attributes do
              uuid_primary_key :id
            end

            actions do
              read :read do
                primary? true
                public? true
              end
            end

            expo do
              action :read
            end
          end
        end

      assert error.message =~ "but not AshTypescript.Resource"
    end

    test "out-of-domain transport and offline values are refused by the schema" do
      assert_raise Spark.Error.DslError, ~r/transport/, fn ->
        defmodule Elixir.AshExpoHardening.BadTransport do
          use Ash.Resource,
            domain: nil,
            extensions: [AshTypescript.Resource, AshExpo.Resource]

          typescript do
            type_name "BadTransport"
          end

          attributes do
            uuid_primary_key :id
          end

          actions do
            defaults [:read]
          end

          expo do
            action :read, transport: :websocket
          end
        end
      end

      assert_raise Spark.Error.DslError, ~r/offline/, fn ->
        defmodule Elixir.AshExpoHardening.BadOffline do
          use Ash.Resource,
            domain: nil,
            extensions: [AshTypescript.Resource, AshExpo.Resource]

          typescript do
            type_name "BadOffline"
          end

          attributes do
            uuid_primary_key :id
          end

          actions do
            defaults [:read]
          end

          expo do
            action :read, offline: :always
          end
        end
      end
    end
  end

  describe "manifest admission" do
    test "non-resource inputs are refused with a typed ArgumentError" do
      for bad <- [String, AshExpo.Integration.Domain, :no_such_module_ash_expo, "Todo", nil] do
        error = assert_raise ArgumentError, fn -> AshExpo.Manifest.build([bad]) end
        assert error.message =~ "expects Ash resource modules; got #{inspect(bad)}"
      end
    end

    test "a non-list input is refused with a typed ArgumentError" do
      for bad <- [Ordered, nil, %{}, {Ordered}] do
        error = assert_raise ArgumentError, fn -> AshExpo.Manifest.build(bad) end
        assert error.message =~ "expects a list of Ash resource modules; got #{inspect(bad)}"
      end
    end

    test "a refused element poisons the whole build (no partial manifest)" do
      assert_raise ArgumentError, fn ->
        AshExpo.Manifest.build([Ordered, String])
      end
    end

    test "duplicate delivery of a resource is idempotent" do
      once = AshExpo.Manifest.build([Ordered])
      assert AshExpo.Manifest.build([Ordered, Ordered]) == once
    end

    test "resources without the extension or with enabled? false are excluded" do
      assert AshExpo.Manifest.build([Plain, Disabled]) == %{
               "schemaVersion" => AshExpo.schema_version(),
               "resources" => []
             }

      refute AshExpo.Info.enabled?(Disabled)
      refute AshExpo.Info.ash_expo_resource?(Plain)
    end

    test "DSL declaration order does not leak into the manifest (reordering)" do
      [todo] = AshExpo.Manifest.build([Ordered])["resources"]
      [reordered] = AshExpo.Manifest.build([Reordered])["resources"]

      assert Enum.map(AshExpo.Info.actions(Reordered), & &1.name) == [:create, :read]
      assert reordered["actions"] == todo["actions"]
    end
  end

  describe "generated-file court (stale subject / wrong digest)" do
    setup do
      dir =
        Path.join(
          System.tmp_dir!(),
          "ash_expo_court_#{System.unique_integer([:positive])}"
        )

      on_exit(fn -> File.rm_rf!(dir) end)
      {:ok, dir: dir}
    end

    test "write! is idempotent and check! admits the written tree", %{dir: dir} do
      resources = [Ordered]
      written = AshExpo.Codegen.write!(resources, dir)
      assert length(written) == 3
      assert AshExpo.Codegen.write!(resources, dir) == []
      assert AshExpo.Codegen.check!(resources, dir) == :ok
    end

    test "a single flipped byte is refused and only that path is named", %{dir: dir} do
      resources = [Ordered]
      AshExpo.Codegen.write!(resources, dir)
      manifest = Path.join(dir, "ash_expo_manifest.ts")
      <<first, rest::binary>> = File.read!(manifest)
      File.write!(manifest, <<Bitwise.bxor(first, 1), rest::binary>>)

      error = assert_raise RuntimeError, fn -> AshExpo.Codegen.check!(resources, dir) end
      assert error.message == "AshExpo generated files are stale: #{manifest}"

      assert AshExpo.Codegen.write!(resources, dir) == [manifest]
      assert AshExpo.Codegen.check!(resources, dir) == :ok
    end

    test "a stale subject (resource set changed) is refused", %{dir: dir} do
      AshExpo.Codegen.write!([Ordered], dir)

      error =
        assert_raise RuntimeError, fn ->
          AshExpo.Codegen.check!([Ordered, Reordered], dir)
        end

      assert error.message =~ "ash_expo_manifest.ts"
      refute error.message =~ "ash_expo_runtime.ts"
    end

    test "missing files and a directory in place of a file are stale, not crashes",
         %{dir: dir} do
      resources = [Ordered]
      error = assert_raise RuntimeError, fn -> AshExpo.Codegen.check!(resources, dir) end
      assert error.message =~ "ash_expo.ts"

      AshExpo.Codegen.write!(resources, dir)
      runtime = Path.join(dir, "ash_expo_runtime.ts")
      File.rm!(runtime)
      File.mkdir_p!(runtime)

      error = assert_raise RuntimeError, fn -> AshExpo.Codegen.check!(resources, dir) end
      assert error.message == "AshExpo generated files are stale: #{runtime}"

      error = assert_raise RuntimeError, fn -> AshExpo.Codegen.write!(resources, dir) end

      assert error.message ==
               "AshExpo refuses to overwrite #{runtime}: expected a regular file, found directory"

      assert File.dir?(runtime)
    end

    test "write! regenerates a missing file and leaves current files untouched",
         %{dir: dir} do
      resources = [Ordered]
      AshExpo.Codegen.write!(resources, dir)
      index = Path.join(dir, "ash_expo.ts")
      File.rm!(index)

      assert AshExpo.Codegen.write!(resources, dir) == [index]
      assert AshExpo.Codegen.write!(resources, dir) == []
      assert AshExpo.Codegen.check!(resources, dir) == :ok
    end
  end
end

defmodule AshExpoHardening.ChannelConfigCourtTest do
  @moduledoc """
  Channel projections are admitted only when ash_typescript is configured to
  generate Phoenix Channel RPC actions. Mutates real application env, so it is
  synchronous and restores the prior value.
  """
  use ExUnit.Case, async: false

  require Spark.Test

  test "channel transport without generate_phx_channel_rpc_actions is refused" do
    prior = Application.get_env(:ash_typescript, :generate_phx_channel_rpc_actions)
    Application.put_env(:ash_typescript, :generate_phx_channel_rpc_actions, false)

    try do
      error =
        Spark.Test.assert_dsl_error %Spark.Error.DslError{path: [:expo]} do
          defmodule Elixir.AshExpoHardening.ChannelWithoutConfig do
            use Ash.Resource,
              domain: nil,
              extensions: [AshTypescript.Resource, AshExpo.Resource]

            typescript do
              type_name "ChannelWithoutConfig"
            end

            attributes do
              uuid_primary_key :id
            end

            actions do
              read :read do
                primary? true
                public? true
              end
            end

            expo do
              action :read, transport: :channel, realtime?: true
            end
          end
        end

      assert error.message =~ "generate_phx_channel_rpc_actions: true"
    after
      Application.put_env(:ash_typescript, :generate_phx_channel_rpc_actions, prior)
    end
  end
end

defmodule AshExpoHardening.CompileEnvTracer do
  @moduledoc false
  # Real compiler tracer: records every {:compile_env, ...} event the Elixir
  # compiler emits, keyed by the module being compiled, into a public ETS table.
  @table :ash_expo_compile_env_trace

  def table, do: @table

  def trace({:compile_env, app, path, value}, %Macro.Env{module: module}) do
    if :ets.whereis(@table) != :undefined do
      :ets.insert(@table, {module, app, path, value})
    end

    :ok
  end

  def trace(_event, _env), do: :ok
end

defmodule AshExpoHardening.ChannelCompileEnvCourtTest do
  @moduledoc """
  A resource with a channel projection must record
  `:ash_typescript, :generate_phx_channel_rpc_actions` as compile env, so Mix
  recompiles it when that config changes. Uses the real compiler with a real
  tracer; mutates global compiler options, so it is synchronous and restores
  them.
  """
  use ExUnit.Case, async: false

  alias AshExpoHardening.CompileEnvTracer

  @key [:generate_phx_channel_rpc_actions]

  defp compile_resource(module, transport) do
    source = """
    defmodule #{inspect(module)} do
      use Ash.Resource,
        domain: nil,
        extensions: [AshTypescript.Resource, AshExpo.Resource]

      typescript do
        type_name "#{module |> Module.split() |> List.last()}"
      end

      attributes do
        uuid_primary_key :id
      end

      actions do
        read :read do
          primary? true
          public? true
        end
      end

      expo do
        action :read, transport: #{inspect(transport)}
      end
    end
    """

    Code.compile_string(source, "compile_env_court_#{transport}.exs")
  end

  test "channel projections trace the ash_typescript channel key; http ones do not" do
    table = :ets.new(CompileEnvTracer.table(), [:named_table, :public, :bag])
    prior_tracers = Code.get_compiler_option(:tracers)
    Code.put_compiler_option(:tracers, [CompileEnvTracer | prior_tracers])

    try do
      compile_resource(AshExpoHardening.CompileEnvChannel, :channel)
      compile_resource(AshExpoHardening.CompileEnvHttp, :http)

      assert :ets.lookup(table, AshExpoHardening.CompileEnvChannel) ==
               [{AshExpoHardening.CompileEnvChannel, :ash_typescript, @key, {:ok, true}}]

      assert :ets.lookup(table, AshExpoHardening.CompileEnvHttp) == []
      assert AshExpoHardening.CompileEnvChannel.__ash_expo_channel_rpc_actions__() == true

      refute function_exported?(
               AshExpoHardening.CompileEnvHttp,
               :__ash_expo_channel_rpc_actions__,
               0
             )
    after
      Code.put_compiler_option(:tracers, prior_tracers)
      :ets.delete(table)
    end
  end
end
