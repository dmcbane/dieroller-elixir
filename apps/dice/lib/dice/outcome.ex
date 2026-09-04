defmodule Dice.Outcome do
  @moduledoc """
  The result of rolling a whole `Dice.Expr`.

  `groups` holds one `Dice.Roll` per dice term, in the order they appear in the
  expression; constant terms contribute to the totals but have no group.
  `subtotal` is the signed sum of every term, `total` that sum after any `*n`.
  """

  defstruct [:expr, :groups, :subtotal, :total]

  @type t :: %__MODULE__{
          expr: Dice.Expr.t(),
          groups: [Dice.Roll.t()],
          subtotal: integer(),
          total: integer()
        }
end
