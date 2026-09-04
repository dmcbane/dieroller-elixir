defmodule DierollerCLI do
  @moduledoc """
  Command line entry point for `dieroller`.

  `run/1` is pure apart from the RNG: it turns an argument list into either a
  lazy stream of output chunks or an error message. `main/1` is the only part
  that touches IO and process exit status, which keeps the whole CLI testable
  in-process while letting `--iterations` stream rather than buffer.
  """

  alias Dice.{Expr, Notation, Spec}
  alias DierollerCLI.Help

  @hint "Try 'dieroller --help' for more information."

  @switches [
    verbose: :boolean,
    dice: :integer,
    keep: :integer,
    modifier: :string,
    sides: :integer,
    iterations: :integer,
    json: :boolean,
    seed: :integer,
    help: :boolean
  ]

  @aliases [
    v: :verbose,
    d: :dice,
    k: :keep,
    m: :modifier,
    s: :sides,
    i: :iterations,
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

  `output` is a lazy enumerable of chunks, so a large `--iterations` streams to
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
    if opts[:help] do
      {:ok, [Help.text()]}
    else
      with {:ok, iterations} <- iterations(opts),
           {:ok, expr} <- build_expr(opts, args) do
        if seed = opts[:seed], do: Dice.seed(seed)
        {:ok, render(expr, iterations, opts)}
      end
    end
  end

  defp iterations(opts) do
    case Keyword.get(opts, :iterations, 1) do
      n when n > 0 -> {:ok, n}
      _ -> {:error, "iterations must be greater than 0."}
    end
  end

  # A leading positional in dice notation short-circuits the legacy form.
  defp build_expr(opts, [first | rest] = args) do
    if Notation.dice_like?(first) do
      case rest do
        [] -> Notation.parse(first)
        extra -> {:error, "unexpected arguments after dice notation: #{Enum.join(extra, " ")}"}
      end
    else
      with {:ok, spec} <- legacy_spec(opts, args), do: {:ok, Expr.from_spec(spec)}
    end
  end

  defp build_expr(opts, []) do
    with {:ok, spec} <- legacy_spec(opts, []), do: {:ok, Expr.from_spec(spec)}
  end

  # The original merged flags and positionals slot by slot, with positionals
  # winning. Reproduced here so existing invocations behave identically.
  defp legacy_spec(opts, args) do
    with {:ok, dice} <- slot(args, 0, Keyword.get(opts, :dice, 1), "dice"),
         {:ok, sides} <- slot(args, 1, Keyword.get(opts, :sides, 20), "sides"),
         {:ok, modifier} <- modifier_slot(args, opts),
         {:ok, keep} <- keep_slot(args, opts, dice) do
      {op, amount} = modifier
      Spec.new(dice: dice, sides: sides, keep: keep, op: op, amount: amount)
    end
  end

  defp slot(args, index, default, name) do
    case Enum.at(args, index) do
      nil -> {:ok, default}
      raw -> integer(raw, name)
    end
  end

  defp modifier_slot(args, opts) do
    Notation.parse_modifier(Enum.at(args, 2) || Keyword.get(opts, :modifier, "0"))
  end

  defp keep_slot(args, opts, dice) do
    case Enum.at(args, 3) do
      # The original used 0 as a sentinel for "--keep not given" and silently
      # rewrote it to `dice`. OptionParser reports absence directly, so an
      # explicit `--keep 0` can fall through to validation the way the help
      # text already promised it would.
      nil -> {:ok, Keyword.get(opts, :keep) || dice}
      raw -> integer(raw, "keep")
    end
  end

  defp integer(raw, name) do
    case Integer.parse(raw) do
      {value, ""} -> {:ok, value}
      _ -> {:error, ~s(#{name} must be a number, got "#{raw}".)}
    end
  end

  defp render(expr, iterations, opts) do
    notation = Expr.notation(expr)

    format =
      cond do
        opts[:json] -> &json_line(&1, notation)
        opts[:verbose] -> &verbose_line(&1, notation)
        true -> &"#{&1.total}\n"
      end

    expr
    |> Dice.stream()
    |> Stream.map(format)
    |> Stream.take(iterations)
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
