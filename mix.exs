defmodule AshExpo.MixProject do
  use Mix.Project

  @version "0.1.0-dev"
  @source_url "https://github.com/seanchatmangpt/ash_expo"

  def project do
    [
      app: :ash_expo,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Expo runtime and code generation for Ash Framework applications",
      source_url: @source_url,
      homepage_url: @source_url,
      package: package(),
      docs: [main: "readme", extras: ["README.md"]]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ash, "~> 3.33"},
      {:ash_typescript, "~> 0.18.2"},
      {:spark, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md)
    ]
  end
end
