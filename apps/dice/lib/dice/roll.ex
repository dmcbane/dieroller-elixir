defmodule Dice.Roll do
  @moduledoc """
  The outcome of rolling a `Dice.Spec`.

  `rolled` holds every die in the order it came up; `kept` holds the highest
  `keep` of them, sorted descending. `subtotal` is the sum of `kept` before the
  modifier, `total` after it.
  """

  defstruct [:spec, :rolled, :kept, :subtotal, :total]

  @type t :: %__MODULE__{
          spec: Dice.Spec.t(),
          rolled: [pos_integer()],
          kept: [pos_integer()],
          subtotal: integer(),
          total: integer()
        }
end
