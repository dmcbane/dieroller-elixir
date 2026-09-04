defmodule Dice do
  @moduledoc """
  Rolling dice.

  This module is pure with respect to IO: every entry point returns data, and
  formatting lives in the CLI applications. The only side effect is the process
  RNG, which `seed/1` makes reproducible.
  """

  alias Dice.{Batch, Expr, Outcome, Roll, Spec}

  @doc """
  Rolls a spec once.

      iex> Dice.seed(42)
      iex> {:ok, spec} = Dice.Spec.new(dice: 4, sides: 6, keep: 3)
      iex> roll = Dice.roll(spec)
      iex> length(roll.rolled) == 4 and length(roll.kept) == 3
      true
  """
  @spec roll(Spec.t()) :: Roll.t()
  def roll(%Spec{} = spec) do
    rolled = Enum.map(1..spec.dice//1, fn _ -> :rand.uniform(spec.sides) end)
    kept = Spec.select(spec, rolled)
    subtotal = Enum.sum(kept)

    %Roll{
      spec: spec,
      rolled: rolled,
      kept: kept,
      subtotal: subtotal,
      total: Spec.apply_modifier(spec, subtotal)
    }
  end

  @doc """
  Rolls a whole expression, one group per dice term.

      iex> Dice.seed(1)
      iex> {:ok, expr} = Dice.Notation.parse("2d6+1d8-1")
      iex> outcome = Dice.roll_expr(expr)
      iex> length(outcome.groups)
      2
  """
  @spec roll_expr(Expr.t()) :: Outcome.t()
  def roll_expr(%Expr{terms: terms, scale: scale} = expr) do
    {groups, subtotal} =
      Enum.reduce(terms, {[], 0}, fn
        {sign, %Spec{} = spec}, {groups, sum} ->
          rolled = roll(spec)
          {[rolled | groups], combine(sign, sum, rolled.total)}

        {sign, constant}, {groups, sum} when is_integer(constant) ->
          {groups, combine(sign, sum, constant)}
      end)

    %Outcome{
      expr: expr,
      groups: Enum.reverse(groups),
      subtotal: subtotal,
      total: if(scale, do: subtotal * scale, else: subtotal)
    }
  end

  defp combine(:+, sum, value), do: sum + value
  defp combine(:-, sum, value), do: sum - value

  @doc """
  A lazy stream of rolls of the same expression or spec.

  Given an expression or a spec the stream is infinite, and a caller bounds it
  with `Enum.take/2`. Given a `Dice.Batch` it is already bounded by the batch's
  repeat count, since that is what the count is for.

      iex> Dice.seed(3)
      iex> {:ok, batch} = Dice.Notation.parse_roll("6x1d1")
      iex> batch |> Dice.stream() |> Enum.map(& &1.total)
      [1, 1, 1, 1, 1, 1]
  """
  @spec stream(Batch.t() | Expr.t() | Spec.t()) :: Enumerable.t()
  def stream(%Expr{} = expr), do: Stream.repeatedly(fn -> roll_expr(expr) end)
  def stream(%Spec{} = spec), do: Stream.repeatedly(fn -> roll(spec) end)

  def stream(%Batch{expr: expr, repeat: repeat}), do: expr |> stream() |> Stream.take(repeat)

  @doc """
  Seeds the calling process's RNG so a run is reproducible.

  Passing the same integer twice yields the same sequence of rolls.
  """
  @spec seed(integer()) :: :ok
  def seed(n) when is_integer(n) do
    :rand.seed(:exsss, {n, n + 1, n + 2})
    :ok
  end
end
