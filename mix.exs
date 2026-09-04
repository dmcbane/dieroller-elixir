defmodule Dieroller.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "1.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  defp deps do
    [
      {:burrito, "~> 1.6"}
    ]
  end

  # Each CLI ships as its own self-contained binary, matching what `raco exe`
  # produced for the Racket original: no Erlang install needed on the target.
  defp releases do
    [
      dieroller: burrito_release(:dieroller_cli),
      pathfinder_character: burrito_release(:pathfinder_cli)
    ]
  end

  defp burrito_release(app) do
    [
      applications: [{app, :permanent}],
      steps: [:assemble, &Burrito.wrap/1],
      burrito: [
        # Add `windows: [os: :windows, cpu: :x86_64]` to cross-compile for
        # Windows. That target unpacks a Windows ERTS installer and so also
        # needs 7z (`apt install p7zip-full`) alongside Zig.
        targets: [
          linux: [os: :linux, cpu: :x86_64]
        ]
      ]
    ]
  end
end
