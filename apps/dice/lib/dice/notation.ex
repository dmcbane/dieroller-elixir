defmodule Dice.Notation do
  @moduledoc """
  Parsing of dice notation (`4d6k3+2`) and of the bare modifier argument the
  original command line accepted (`+3`, `-1`, `*2`, or a lone `3`).
  """

  alias Dice.Spec

  @notation ~r/^(\d+)[dD](\d+)(?:[kK](\d+))?(?:\s*([-+*])\s*(\d+))?$/
  @ops %{"+" => :+, "-" => :-, "*" => :*}

  @doc """
  Returns true when the string looks like dice notation.

  The CLI uses this to decide whether a leading positional argument is notation
  or the legacy `<dice> <sides> <modifier> <keep>` form.

      iex> Dice.Notation.notation?("4d6k3")
      true

      iex> Dice.Notation.notation?("5")
      false
  """
  @spec notation?(String.t()) :: boolean()
  def notation?(string), do: Regex.match?(@notation, String.trim(string))

  @doc """
  Parses dice notation into a validated `Dice.Spec`.

      iex> Dice.Notation.parse("4d6k3+2")
      {:ok, %Dice.Spec{dice: 4, sides: 6, keep: 3, op: :+, amount: 2}}

      iex> Dice.Notation.parse("2D10")
      {:ok, %Dice.Spec{dice: 2, sides: 10, keep: 2, op: :+, amount: 0}}

      iex> Dice.Notation.parse("d20")
      {:error, ~s(could not parse dice notation: "d20")}
  """
  @spec parse(String.t()) :: {:ok, Spec.t()} | {:error, String.t()}
  def parse(string) do
    trimmed = String.trim(string)

    case Regex.run(@notation, trimmed, capture: :all_but_first) do
      nil -> {:error, ~s(could not parse dice notation: "#{trimmed}")}
      captures -> build(captures)
    end
  end

  # Regex.run drops trailing groups that did not participate, so pad back to
  # the full arity before destructuring.
  defp build(captures) do
    [dice, sides, keep, op, amount] = captures ++ List.duplicate("", 5 - length(captures))

    Spec.new(
      dice: String.to_integer(dice),
      sides: String.to_integer(sides),
      keep: optional_integer(keep),
      op: Map.get(@ops, op, :+),
      amount: optional_integer(amount) || 0
    )
  end

  defp optional_integer(""), do: nil
  defp optional_integer(digits), do: String.to_integer(digits)

  @doc """
  Parses a standalone modifier argument.

  A leading `+`, `-`, or `*` selects the operation; without one, `+` is assumed.

      iex> Dice.Notation.parse_modifier("+3")
      {:ok, {:+, 3}}

      iex> Dice.Notation.parse_modifier("*2")
      {:ok, {:*, 2}}

      iex> Dice.Notation.parse_modifier("4")
      {:ok, {:+, 4}}
  """
  @spec parse_modifier(String.t()) :: {:ok, {Spec.op(), non_neg_integer()}} | {:error, String.t()}
  def parse_modifier(string) do
    case String.trim(string) do
      <<sign::binary-size(1), rest::binary>> when is_map_key(@ops, sign) ->
        with {:ok, amount} <- integer(rest, string), do: {:ok, {@ops[sign], amount}}

      other ->
        with {:ok, amount} <- integer(other, string), do: {:ok, {:+, amount}}
    end
  end

  defp integer(digits, original) do
    case Integer.parse(String.trim(digits)) do
      {amount, ""} -> {:ok, amount}
      _ -> {:error, ~s(could not parse modifier: "#{original}")}
    end
  end
end
