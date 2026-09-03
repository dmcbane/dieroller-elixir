defmodule PathfinderCLI.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Under `mix test` and `iex -S mix` this app starts as an ordinary
    # dependency and must not take over the terminal. Burrito sets __BURRITO in
    # the wrapped binary's environment, which is what running_standalone?/0
    # checks, so only the shipped executable takes the CLI path.
    if Burrito.Util.running_standalone?() do
      Burrito.Util.Args.argv() |> PathfinderCLI.main()
      System.halt(0)
    end

    Supervisor.start_link([], strategy: :one_for_one, name: __MODULE__)
  end
end
