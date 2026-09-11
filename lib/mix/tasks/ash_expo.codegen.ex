defmodule Mix.Tasks.AshExpo.Codegen do
  @moduledoc """
  Generates Expo runtime support and the mobile action manifest.

      mix ash_expo.codegen
      mix ash_expo.codegen --check
      mix ash_expo.codegen --output apps/mobile/generated/ash

  Resources are discovered from the current OTP application's configured Ash
  domains. Only resources using `AshExpo.Resource` are included.
  """

  @shortdoc "Generates AshExpo client support"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")

    {opts, _remaining, _invalid} =
      OptionParser.parse(args,
        switches: [check: :boolean, output: :string],
        aliases: [o: :output]
      )

    otp_app = Mix.Project.config()[:app]
    resources = AshExpo.Manifest.resources_for_app(otp_app)
    output = Keyword.get(opts, :output, Application.get_env(:ash_expo, :output, "assets/js"))

    if opts[:check] do
      AshExpo.Codegen.check!(resources, output)
      Mix.shell().info("AshExpo generated files are current")
    else
      case AshExpo.Codegen.write!(resources, output) do
        [] -> Mix.shell().info("AshExpo generated files are current")
        paths -> Enum.each(paths, &Mix.shell().info("generated #{&1}"))
      end
    end
  end
end
