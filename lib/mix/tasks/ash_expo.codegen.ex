defmodule Mix.Tasks.AshExpo.Codegen do
  @moduledoc """
  Generates Expo runtime support and the mobile action manifest.

      mix ash_expo.codegen
      mix ash_expo.codegen --check
      mix ash_expo.codegen --dry-run
      mix ash_expo.codegen --output apps/mobile/generated/ash

  Resources are discovered from the current OTP application's configured Ash
  domains. Only resources using `AshExpo.Resource` are included.

  This task is also invoked automatically by `mix ash.codegen` when an Ash
  resource uses `AshExpo.Resource`.
  """

  @shortdoc "Generates AshExpo client support"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")

    {opts, _remaining, _invalid} =
      OptionParser.parse(args,
        switches: [
          check: :boolean,
          dry_run: :boolean,
          dev: :boolean,
          name: :string,
          output: :string
        ],
        aliases: [o: :output]
      )

    otp_app = Mix.Project.config()[:app]
    resources = AshExpo.Manifest.resources_for_app(otp_app)
    output = Keyword.get(opts, :output, Application.get_env(:ash_expo, :output, "assets/js"))

    cond do
      opts[:check] ->
        AshExpo.Codegen.check!(resources, output)
        Mix.shell().info("AshExpo generated files are current")

      opts[:dry_run] ->
        resources
        |> AshExpo.Codegen.generate(output)
        |> Enum.sort_by(&elem(&1, 0))
        |> Enum.each(fn {path, content} ->
          Mix.shell().info("## #{path}\n\n#{content}")
        end)

      true ->
        case AshExpo.Codegen.write!(resources, output) do
          [] -> Mix.shell().info("AshExpo generated files are current")
          paths -> Enum.each(paths, &Mix.shell().info("generated #{&1}"))
        end
    end
  end
end
