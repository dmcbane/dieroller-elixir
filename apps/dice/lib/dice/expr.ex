defmodule Dice.Expr do
  @moduledoc """
  A whole dice expression: one or more signed terms, optionally scaled.

  A term is either a dice group (`2d6`, `4d6k3`) or a plain constant, so
  `2d6+1d8-1` is three terms. `scale` carries a trailing `*n`, which multiplies
  the total of every term -- the same meaning `*` had when it was the only
  modifier the command line accepted.
  """

  alias Dice.Spec

  defstruct terms: [], scale: nil

  @type sign :: :+ | :-
  @type term_value :: Spec.t() | integer()
  @type t :: %__MODULE__{terms: [{sign(), term_value()}], scale: pos_integer() | nil}

  @doc """
  Wraps a single `Dice.Spec` as an expression, preserving its modifier.

      iex> {:ok, spec} = Dice.Spec.new(dice: 3, sides: 6, op: :+, amount: 2)
      iex> Dice.Expr.from_spec(spec) |> Dice.Expr.notation()
      "3D6+2"

      iex> {:ok, spec} = Dice.Spec.new(dice: 3, sides: 6, op: :*, amount: 2)
      iex> Dice.Expr.from_spec(spec) |> Dice.Expr.notation()
      "3D6*2"
  """
  @spec from_spec(Spec.t()) :: t()
  def from_spec(%Spec{op: :*, amount: amount} = spec) do
    %__MODULE__{terms: [{:+, bare(spec)}], scale: amount}
  end

  # An exactly-zero addition is the "no modifier" case and adds no term, which is
  # what keeps `3D6` rendering without a trailing `+0`.
  def from_spec(%Spec{op: :+, amount: 0} = spec) do
    %__MODULE__{terms: [{:+, bare(spec)}]}
  end

  def from_spec(%Spec{op: op, amount: amount} = spec) do
    %__MODULE__{terms: [{:+, bare(spec)}, {op, amount}]}
  end

  defp bare(spec), do: %{spec | op: :+, amount: 0}

  @doc """
  Renders the expression in canonical notation.

      iex> {:ok, a} = Dice.Spec.new(dice: 2, sides: 6)
      iex> {:ok, b} = Dice.Spec.new(dice: 1, sides: 8)
      iex> Dice.Expr.notation(%Dice.Expr{terms: [{:+, a}, {:+, b}, {:-, 1}]})
      "2D6+1D8-1"
  """
  @spec notation(t()) :: String.t()
  def notation(%__MODULE__{terms: terms, scale: scale}) do
    terms
    |> Enum.with_index()
    |> Enum.map_join(fn {{sign, value}, index} -> render(sign, value, index) end)
    |> then(fn rendered -> if scale, do: rendered <> "*#{scale}", else: rendered end)
  end

  # A leading plus is implicit; every later term carries its sign.
  defp render(:+, value, 0), do: text(value)
  defp render(sign, value, _index), do: "#{sign}#{text(value)}"

  defp text(%Spec{} = spec), do: Spec.notation(spec)
  defp text(constant) when is_integer(constant), do: Integer.to_string(constant)

  @doc "The dice groups in the expression, in order, ignoring constant terms."
  @spec specs(t()) :: [Spec.t()]
  def specs(%__MODULE__{terms: terms}) do
    for {_sign, %Spec{} = spec} <- terms, do: spec
  end
end
