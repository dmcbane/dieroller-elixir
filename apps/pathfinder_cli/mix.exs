defmodule PathfinderCLI.MixProject do
  use Mix.Project

  def project do
    [
      app: :pathfinder_cli,
      version: "1.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: PathfinderCLI, name: "pathfinder-character"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {PathfinderCLI.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dice, in_umbrella: true},
      {:burrito, "~> 1.6"}
    ]
  end
end
