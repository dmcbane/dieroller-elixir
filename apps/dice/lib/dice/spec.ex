defmodule Dice.Spec do
  @moduledoc """
  A validated dice-rolling request.

  A spec says: roll `dice` dice of `sides` sides each, keep the `keep` highest
  results, then apply `op` with `amount` to the sum of what was kept.

  The modifier applies to the *sum*, not to each die, so `:*` multiplies the
  whole kept total.
  """

  defstruct dice: 1, sides: 20, keep: nil, op: :+, amount: 0

  @type op :: :+ | :- | :*

  @type t :: %__MODULE__{
          dice: pos_integer(),
          sides: pos_integer(),
          keep: pos_integer(),
          op: op(),
          amount: non_neg_integer()
        }

  @doc """
  Builds a validated spec from a keyword list or map.

  `:keep` defaults to `:dice`, so by default every die counts.

      iex> Dice.Spec.new(dice: 3, sides: 6)
      {:ok, %Dice.Spec{dice: 3, sides: 6, keep: 3, op: :+, amount: 0}}

      iex> Dice.Spec.new(dice: 2, keep: 5)
      {:error, "dice must be greater than or equal to keep."}
  """
  @spec new(Enumerable.t()) :: {:ok, t()} | {:error, String.t()}
  def new(fields \\ []) do
    spec = struct(__MODULE__, fields)
    validate(%{spec | keep: spec.keep || spec.dice})
  end

  # Checks run in the same order as the Racket original, so an input with more
  # than one problem reports the same message it always did.
  defp validate(%__MODULE__{} = spec) do
    cond do
      spec.dice < 1 -> {:error, "dice must be greater than 0."}
      spec.keep < 1 -> {:error, "keep must be greater than 0."}
      spec.dice < spec.keep -> {:error, "dice must be greater than or equal to keep."}
      spec.sides < 1 -> {:error, "sides must be greater than 0."}
      true -> {:ok, spec}
    end
  end

  @doc """
  Renders the spec in canonical dice notation.

  The `K` clause is omitted when every die is kept, and the modifier is omitted
  only when it is exactly `+0` -- `*0` and `-0` still print, because they change
  the result.

      iex> {:ok, spec} = Dice.Spec.new(dice: 4, sides: 6, keep: 3, op: :+, amount: 2)
      iex> Dice.Spec.notation(spec)
      "4D6K3+2"

      iex> {:ok, spec} = Dice.Spec.new(dice: 1, sides: 20)
      iex> Dice.Spec.notation(spec)
      "1D20"
  """
  @spec notation(t()) :: String.t()
  def notation(%__MODULE__{} = spec) do
    "#{spec.dice}D#{spec.sides}#{keep_part(spec)}#{modifier_part(spec)}"
  end

  defp keep_part(%__MODULE__{dice: same, keep: same}), do: ""
  defp keep_part(%__MODULE__{keep: keep}), do: "K#{keep}"

  defp modifier_part(%__MODULE__{op: :+, amount: 0}), do: ""
  defp modifier_part(%__MODULE__{op: op, amount: amount}), do: "#{op}#{amount}"

  @doc """
  Applies the spec's modifier to an already-summed roll.

      iex> {:ok, spec} = Dice.Spec.new(dice: 3, sides: 6, op: :*, amount: 2)
      iex> Dice.Spec.apply_modifier(spec, 10)
      20
  """
  @spec apply_modifier(t(), integer()) :: integer()
  def apply_modifier(%__MODULE__{op: :+, amount: amount}, sum), do: sum + amount
  def apply_modifier(%__MODULE__{op: :-, amount: amount}, sum), do: sum - amount
  def apply_modifier(%__MODULE__{op: :*, amount: amount}, sum), do: sum * amount
end
