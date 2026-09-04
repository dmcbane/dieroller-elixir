defmodule DierollerCLI do
  @moduledoc """
  Command line entry point for `dieroller`.

  The roll is described entirely by its dice expression, so the only options
  left are the ones that are not part of a roll: how to present it, how to seed
  it, and the two informational flags.

  `run/1` is pure apart from the RNG: it turns an argument list into either a
  lazy stream of output chunks or an error message. `main/1` is the only part
  that touches IO and process exit status, which keeps the whole CLI testable
  in-process while letting a large repeat count stream rather than buffer.

  An aggregated roll -- `sum(6x4d6k3)` -- is the one thing that cannot stream
  all the way, since its answer depends on every roll; only its summary waits,
  and under `--verbose` the rolls still appear as they are made.
  """

  alias Dice.{Aggregate, Batch, Expr, Notation, Spec}
  alias DierollerCLI.Help

  @version Mix.Project.config()[:version]

  @hint "Try 'dieroller --help' for more information."

  @switches [verbose: :boolean, json: :boolean, seed: :integer, help: :boolean, version: :boolean]

  @aliases [v: :verbose, j: :json, h: :help, V: :version]

  # The <dice> <sides> <modifier> <keep> form these replaced.
  @legacy ~r/^[-+*]?\d+$/

  @doc false
  def main(argv) do
    case run(argv) do
      {:ok, output} ->
        write(output)

      {:error, message} ->
        IO.puts(:stderr, message)
        IO.puts(:stderr, @hint)
        System.halt(1)
    end
  end

  # Writing to a closed pipe is how `dieroller ... | head` ends, and the shell
  # convention is to stop quietly rather than report it as a failure.
  defp write(output) do
    Enum.each(output, &IO.write/1)
  rescue
    ErlangError -> :ok
  end

  @doc """
  Turns an argument list into `{:ok, output}` or `{:error, message}`.

  `output` is a lazy enumerable of chunks, so a large repeat count streams to
  the terminal instead of being built in memory first.
  """
  @spec run([String.t()]) :: {:ok, Enumerable.t()} | {:error, String.t()}
  def run(argv) do
    case OptionParser.parse(argv, strict: @switches, aliases: @aliases) do
      {opts, args, []} -> dispatch(opts, args)
      {_, _, [{flag, _} | _]} -> {:error, "unrecognized option #{flag}."}
    end
  end

  defp dispatch(opts, args) do
    cond do
      opts[:help] -> {:ok, [Help.text()]}
      opts[:version] -> {:ok, ["dieroller #{@version}\n"]}
      true -> roll(opts, args)
    end
  end

  defp roll(opts, args) do
    with {:ok, batch} <- expression(args) do
      if seed = opts[:seed], do: Dice.seed(seed)
      {:ok, render(batch, opts)}
    end
  end

  defp expression([]), do: {:error, "no dice expression given."}

  defp expression(args) do
    cond do
      # Caught before parsing so the old positional form gets a migration
      # message rather than "expression contains no dice".
      legacy_form?(args) -> {:error, legacy_hint(args)}
      match?([_], args) -> Notation.parse_roll(hd(args))
      true -> {:error, quoting_hint(args)}
    end
  end

  defp legacy_form?(args) do
    length(args) <= 4 and Enum.all?(args, &Regex.match?(@legacy, &1))
  end

  defp legacy_hint(args) do
    "the <dice> <sides> <modifier> <keep> arguments have been replaced by dice" <>
      " notation; try: dieroller #{suggestion(args)}"
  end

  # Rebuilds the old positional arguments as the equivalent expression.
  defp suggestion([dice]), do: "#{dice}d20"
  defp suggestion([dice, sides]), do: "#{dice}d#{sides}"
  defp suggestion([dice, sides, modifier]), do: "#{dice}d#{sides}#{modifier_text(modifier)}"

  defp suggestion([dice, sides, modifier, keep]),
    do: "#{dice}d#{sides}k#{keep}#{modifier_text(modifier)}"

  defp modifier_text(modifier) do
    case Notation.parse_modifier(modifier) do
      {:ok, {:+, 0}} -> ""
      {:ok, {op, amount}} -> "#{op}#{amount}"
      {:error, _} -> ""
    end
  end

  defp quoting_hint(args) do
    ~s(a roll is one argument; quote the whole expression, ) <>
      ~s(for example: dieroller "#{Enum.join(args, " ")}")
  end

  # Without an aggregate each roll is a line of its own, so the output stays
  # lazy and a huge repeat count costs nothing until it is drained.
  defp render(%Batch{aggregate: nil} = batch, opts) do
    format = per_roll(Batch.notation(batch), opts)

    batch |> Dice.stream() |> Stream.map(format)
  end

  # An aggregate is a property of the whole batch, so it cannot report anything
  # until the last roll is in. The rolls themselves still stream past as they
  # are made; the summary is appended once the batch is exhausted.
  defp render(%Batch{} = batch, opts) do
    show = rolls_shown(batch, opts)

    Stream.transform(
      Dice.stream(batch),
      fn -> [] end,
      fn outcome, totals -> {show.(outcome), [outcome.total | totals]} end,
      fn totals -> {[summary(Enum.reverse(totals), batch, opts)], totals} end,
      fn _totals -> :ok end
    )
  end

  defp per_roll(notation, opts) do
    cond do
      opts[:json] -> &json_line(&1, notation)
      opts[:verbose] -> &verbose_line(&1, notation)
      true -> &"#{&1.total}\n"
    end
  end

  # Verbose shows the rolls behind an aggregate as they happen. JSON does not:
  # its summary object already lists every total, and one object per line is
  # what the un-aggregated form means.
  defp rolls_shown(%Batch{expr: expr}, opts) do
    if opts[:verbose] && !opts[:json] do
      notation = Expr.notation(expr)
      &[verbose_line(&1, notation)]
    else
      fn _outcome -> [] end
    end
  end

  defp summary(totals, %Batch{aggregate: kind} = batch, opts) do
    notation = Batch.notation(batch)
    value = Aggregate.reduce(kind, totals)

    cond do
      opts[:json] ->
        JSON.encode!(%{
          notation: notation,
          aggregate: Atom.to_string(kind),
          expression: Expr.notation(batch.expr),
          repeat: batch.repeat,
          rolls: totals,
          value: value
        }) <> "\n"

      opts[:verbose] ->
        "#{notation} => #{Aggregate.format(kind, totals)}\n"

      true ->
        "#{Aggregate.format(kind, totals)}\n"
    end
  end

  # One parenthesised group per dice term, so a single-group expression reads
  # exactly as it always has: "4D6K3 (5 4 4) => 13".
  defp verbose_line(outcome, notation) do
    groups = Enum.map_join(outcome.groups, " ", &"(#{Enum.join(&1.kept, " ")})")
    "#{notation} #{groups} => #{outcome.total}\n"
  end

  defp json_line(outcome, notation) do
    JSON.encode!(%{
      notation: notation,
      groups:
        Enum.map(outcome.groups, fn group ->
          %{
            notation: Spec.notation(group.spec),
            rolled: group.rolled,
            kept: group.kept,
            sum: group.total
          }
        end),
      subtotal: outcome.subtotal,
      total: outcome.total
    }) <> "\n"
  end
end
