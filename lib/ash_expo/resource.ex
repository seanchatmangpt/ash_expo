defmodule AshExpo.Resource do
  @moduledoc """
  Spark DSL extension for declaring how public Ash actions may be projected to
  Expo clients.

  Example:

      use Ash.Resource,
        extensions: [AshTypescript.Resource, AshExpo.Resource]

      typescript do
        type_name "Todo"
      end

      expo do
        action :read, offline: :cacheable
        action :create, offline: :online_only
        action :subscribe, transport: :channel, realtime?: true
      end

  The DSL does not expose actions by itself. Each named action must already
  exist on the resource and be `public? true`. The projection is verified at
  the Spark DSL boundary and checked again before code generation.
  """

  defmodule Action do
    @moduledoc false
    defstruct [
      :name,
      transport: :http,
      offline: :online_only,
      realtime?: false,
      secure?: true,
      __spark_metadata__: nil
    ]
  end

  @action %Spark.Dsl.Entity{
    name: :action,
    target: Action,
    args: [:name],
    describe: "Projects one existing public Ash action to Expo",
    schema: [
      name: [type: :atom, required: true],
      transport: [
        type: {:in, [:http, :channel]},
        default: :http,
        doc: "Transport used by the generated mobile contract"
      ],
      offline: [
        type: {:in, [:online_only, :cacheable, :idempotent, :replayable]},
        default: :online_only,
        doc: "Offline admission class. No class implies automatic local execution."
      ],
      realtime?: [
        type: :boolean,
        default: false,
        doc: "Marks the action as a realtime capability"
      ],
      secure?: [
        type: :boolean,
        default: true,
        doc: "Whether the client should attach its configured bearer credential"
      ]
    ]
  }

  @expo %Spark.Dsl.Section{
    name: :expo,
    describe: "Expo projection settings for this Ash resource",
    schema: [
      enabled?: [
        type: :boolean,
        default: true,
        doc: "Whether this resource participates in AshExpo code generation"
      ]
    ],
    entities: [@action]
  }

  use Spark.Dsl.Extension,
    sections: [@expo],
    verifiers: [AshExpo.Resource.Verifiers.ValidateProjection]

  @doc false
  def name, do: "ash_expo"

  @doc false
  def codegen(argv) do
    Mix.Task.reenable("ash_expo.codegen")
    Mix.Task.run("ash_expo.codegen", argv)
  end
end
