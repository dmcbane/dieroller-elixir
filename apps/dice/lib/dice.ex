defmodule Dice do
  @moduledoc """
  Rolling dice.

  This module is pure with respect to IO: every entry point returns data, and
  formatting lives in the CLI applications. The only side effect is the process
  RNG, which `seed/1` makes reproducible.
  """

  alias Dice.{Roll, Spec}

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
    kept = rolled |> Enum.sort(:desc) |> Enum.take(spec.keep)
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
  An infinite lazy stream of rolls of the same spec.

  The CLI's `--iterations` is `Enum.take/2` over this.
  """
  @spec stream(Spec.t()) :: Enumerable.t()
  def stream(%Spec{} = spec), do: Stream.repeatedly(fn -> roll(spec) end)

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
