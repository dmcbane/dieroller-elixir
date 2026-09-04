defmodule PathfinderCLI do
  @moduledoc """
  Command line entry point for `pathfinder-character`.

  As with `DierollerCLI`, `run/1` returns data and `main/1` owns all IO, so the
  whole CLI is exercised in-process by the test suite.
  """

  alias Dice.Pathfinder
  alias Dice.Pathfinder.{Character, Purchase}
  alias PathfinderCLI.Help

  @hint "Try 'pathfinder-character --help' for more information."
  @methods [:classic, :standard, :heroic, :pool, :purchase]

  @switches [
    classic: :boolean,
    standard: :boolean,
    heroic: :boolean,
    pool: :string,
    purchase: :string,
    verbose: :boolean,
    number: :integer,
    json: :boolean,
    seed: :integer,
    help: :boolean
  ]

  @aliases [
    c: :classic,
    s: :standard,
    r: :heroic,
    l: :pool,
    p: :purchase,
    v: :verbose,
    n: :number,
    j: :json,
    h: :help
  ]

  @doc false
  def main(argv) do
    case run(argv) do
      {:ok, output} ->
        Enum.each(output, &IO.write/1)

      {:error, message} ->
        IO.puts(:stderr, message)
        IO.puts(:stderr, @hint)
        System.halt(1)
    end
  end

  @doc """
  Turns an argument list into `{:ok, output}` or `{:error, message}`.

  `output` is an enumerable of chunks rather than one large binary.
  """
  @spec run([String.t()]) :: {:ok, Enumerable.t()} | {:error, String.t()}
  def run(argv) do
    case OptionParser.parse(argv, strict: @switches, aliases: @aliases) do
      {opts, [], []} -> dispatch(opts)
      {_, [extra | _], []} -> {:error, ~s(unexpected argument "#{extra}".)}
      {_, _, [{flag, _} | _]} -> {:error, "unrecognized option #{flag}."}
    end
  end

  defp dispatch(opts) do
    if opts[:help] do
      {:ok, [Help.text()]}
    else
      with {:ok, method} <- method(opts) do
        if seed = opts[:seed], do: Dice.seed(seed)

        with {:ok, characters} <- Pathfinder.characters(method, Keyword.get(opts, :number, 1)) do
          {:ok, render(characters, method, opts)}
        end
      end
    end
  end

  # The original declared these mutually exclusive; selecting two is an error
  # here rather than silently letting the last one win.
  defp method(opts) do
    case Enum.filter(@methods, &Keyword.has_key?(opts, &1)) do
      [] ->
        {:ok, :standard}

      [only] ->
        build_method(only, opts)

      chosen ->
        {:error,
         "choose only one generation method (got #{Enum.map_join(chosen, ", ", &"--#{&1}")})."}
    end
  end

  defp build_method(:pool, opts) do
    with {:ok, counts} <- Pathfinder.parse_pool(opts[:pool]), do: {:ok, {:pool, counts}}
  end

  defp build_method(:purchase, opts) do
    with {:ok, campaign} <- Purchase.parse_campaign(opts[:purchase]) do
      {:ok, {:purchase, Purchase.campaign_points(campaign)}}
    end
  end

  defp build_method(rolled, _opts), do: {:ok, rolled}

  defp render(characters, method, opts) do
    format =
      cond do
        opts[:json] -> &json_line(&1, method)
        opts[:verbose] -> &verbose_line/1
        true -> &plain_line/1
      end

    Stream.map(characters, format)
  end

  defp plain_line(%Character{abilities: abilities}), do: "#{Enum.join(abilities, " ")}\n"

  defp verbose_line(%Character{} = character) do
    scores =
      Enum.map_join(Character.labeled(character), " ", fn {name, value} -> "#{name}: #{value}" end)

    "#{scores} (bonus #{character.bonus_total}, cost #{character.cost_total})\n"
  end

  defp json_line(%Character{} = character, method) do
    JSON.encode!(%{
      method: method_name(method),
      abilities: Map.new(Character.labeled(character)),
      scores: character.abilities,
      bonus_total: character.bonus_total,
      cost_total: character.cost_total
    }) <> "\n"
  end

  defp method_name({:pool, counts}), do: "pool #{Enum.join(counts, "/")}"
  defp method_name({:purchase, points}), do: "purchase #{points}"
  defp method_name(rolled), do: Atom.to_string(rolled)
end
