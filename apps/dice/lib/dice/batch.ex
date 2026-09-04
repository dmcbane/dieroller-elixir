defmodule Dice.Batch do
  @moduledoc """
  A whole roll as it was written: an expression, how many times to roll it, and
  what to do with the results.

  `4d6k3` is a batch of one, `6x4d6k3` a batch of six reported one by one, and
  `sum(6x4d6k3)` the same six reduced to a single number by `Dice.Aggregate`.

  This is what `Dice.Notation.parse_roll/1` returns, and the only place the
  repeat count lives: a `Dice.Expr` describes one roll and knows nothing about
  being rolled again.
  """

  alias Dice.{Aggregate, Expr}

  defstruct [:expr, repeat: 1, aggregate: nil]

  @type t :: %__MODULE__{
          expr: Expr.t(),
          repeat: pos_integer(),
          aggregate: Aggregate.t() | nil
        }

  @doc """
  Renders the batch in canonical notation.

  Without an aggregate this is the expression alone, because each line of
  output describes one roll and the repeat count is not part of that roll. An
  aggregate makes the repeat part of the answer -- a sum of six is not a
  property of any one of them -- so it is rendered too.

      iex> {:ok, batch} = Dice.Notation.parse_roll("6x4d6k3")
      iex> Dice.Batch.notation(batch)
      "4D6K3"

      iex> {:ok, batch} = Dice.Notation.parse_roll("sum(6x4d6k3)")
      iex> Dice.Batch.notation(batch)
      "SUM(6x4D6K3)"

      iex> {:ok, batch} = Dice.Notation.parse_roll("max:2d20")
      iex> Dice.Batch.notation(batch)
      "HIGH(1x2D20)"
  """
  @spec notation(t()) :: String.t()
  def notation(%__MODULE__{aggregate: nil, expr: expr}), do: Expr.notation(expr)

  def notation(%__MODULE__{aggregate: kind, repeat: repeat, expr: expr}) do
    "#{Aggregate.notation(kind)}(#{repeat}x#{Expr.notation(expr)})"
  end
end
