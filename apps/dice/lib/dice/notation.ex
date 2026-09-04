defmodule Dice.Notation do
  @moduledoc """
  Parsing of dice notation and of the bare modifier argument the original
  command line accepted (`+3`, `-1`, `*2`, or a lone `3`).

  The grammar is

      roll       := (integer 'x')? expression
      expression := term (('+' | '-') term)* ('*' integer)?
      term       := dice | integer
      dice       := integer 'd' integer selector?
      selector   := 'k' ('h' | 'l')? integer     -- keep, defaulting to highest
                  | 'd' ('h' | 'l')  integer     -- drop

  so `4d6k3`, `2d20kl1` (roll with disadvantage), `4d6dl1` (drop the lowest) and
  `2d6+1d8-1` are all accepted. Drop always needs its direction letter, because
  a bare `d` is already the dice separator.

  A leading repeat count rolls the same expression several times, so `6x4d6k3`
  rolls four dice keeping the best three, six times over. The count is not part
  of the expression itself and does not appear in the rendered notation, since
  that describes a single roll.

  Dropping is stored as keeping from the opposite end, so `4d6dl1` and `4d6k3`
  produce the same spec and both render as `4D6K3`.
  """

  alias Dice.{Expr, Spec}

  @token ~r/^([-+*])?(\d+[dD]\d+(?:[kK][hHlL]?\d+|[dD][hHlL]\d+)?|\d+)/

  @dice ~r/^(?<dice>\d+)[dD](?<sides>\d+)(?:(?<kop>[kK])(?<kdir>[hHlL]?)(?<kn>\d+)|(?<dop>[dD])(?<ddir>[hHlL])(?<dn>\d+))?$/

  @repeat ~r/^(\d+)[xX](.+)$/

  @ops %{"+" => :+, "-" => :-, "*" => :*}

  @doc """
  Parses a whole roll: an optional `<n>x` repeat count, then an expression.

  Unlike `parse/1` this insists the expression contain at least one dice group,
  so a bare constant is reported rather than silently rolling nothing.

      iex> {:ok, {repeat, expr}} = Dice.Notation.parse_roll("6x4d6k3")
      iex> {repeat, Dice.Expr.notation(expr)}
      {6, "4D6K3"}

      iex> {:ok, {repeat, expr}} = Dice.Notation.parse_roll("2d6+1d8-1")
      iex> {repeat, Dice.Expr.notation(expr)}
      {1, "2D6+1D8-1"}

      iex> Dice.Notation.parse_roll("0x3d6")
      {:error, "repeat count must be greater than 0."}

      iex> Dice.Notation.parse_roll("7")
      {:error, ~s(expression contains no dice: "7")}
  """
  @spec parse_roll(String.t()) :: {:ok, {pos_integer(), Expr.t()}} | {:error, String.t()}
  def parse_roll(string) do
    trimmed = String.trim(string)

    {repeat, rest} =
      case Regex.run(@repeat, strip(trimmed), capture: :all_but_first) do
        [count, rest] -> {String.to_integer(count), rest}
        nil -> {1, trimmed}
      end

    if repeat < 1 do
      {:error, "repeat count must be greater than 0."}
    else
      with {:ok, expr} <- parse(rest) do
        case Expr.specs(expr) do
          [] -> {:error, ~s(expression contains no dice: "#{trimmed}")}
          _ -> {:ok, {repeat, expr}}
        end
      end
    end
  end

  @doc """
  Parses a dice expression.

      iex> {:ok, expr} = Dice.Notation.parse("4d6k3+2")
      iex> Dice.Expr.notation(expr)
      "4D6K3+2"

      iex> {:ok, expr} = Dice.Notation.parse("2d20kl1")
      iex> Dice.Expr.notation(expr)
      "2D20KL1"

      iex> {:ok, expr} = Dice.Notation.parse("4d6dl1")
      iex> Dice.Expr.notation(expr)
      "4D6K3"

      iex> {:ok, expr} = Dice.Notation.parse("2d6+1d8-1")
      iex> Dice.Expr.notation(expr)
      "2D6+1D8-1"
  """
  @spec parse(String.t()) :: {:ok, Expr.t()} | {:error, String.t()}
  def parse(string) do
    stripped = strip(string)

    with {:ok, tokens} <- scan(stripped, string, []) do
      build(tokens, string)
    end
  end

  defp strip(string), do: String.replace(string, ~r/\s+/, "")

  defp scan("", _original, []), do: {:error, "no dice expression given."}
  defp scan("", _original, acc), do: {:ok, Enum.reverse(acc)}

  defp scan(rest, original, acc) do
    case Regex.run(@token, rest) do
      nil ->
        {:error, ~s(could not parse dice notation: "#{String.trim(original)}")}

      [matched, sign, body] ->
        remaining = binary_part(rest, byte_size(matched), byte_size(rest) - byte_size(matched))
        scan(remaining, original, [{sign, body} | acc])
    end
  end

  defp build(tokens, original) do
    with {:ok, terms, scale} <- collect(tokens, original, [], nil) do
      {:ok, %Expr{terms: Enum.reverse(terms), scale: scale}}
    end
  end

  # A scale must be the final token, so anything following one is an error.
  defp collect([], _original, terms, scale), do: {:ok, terms, scale}

  defp collect(_tokens, original, _terms, scale) when not is_nil(scale) do
    {:error, ~s(a * multiplier must come last: "#{String.trim(original)}")}
  end

  defp collect([{"*", body} | rest], original, terms, _scale) do
    case Integer.parse(body) do
      {amount, ""} -> collect(rest, original, terms, amount)
      _ -> {:error, ~s(a * multiplier must be a whole number: "#{String.trim(original)}")}
    end
  end

  defp collect([{sign, body} | rest], original, terms, scale) do
    with {:ok, value} <- term(body) do
      collect(rest, original, [{Map.get(@ops, sign, :+), value} | terms], scale)
    end
  end

  defp term(body) do
    case Regex.named_captures(@dice, body) do
      nil -> {:ok, String.to_integer(body)}
      captures -> dice_spec(captures)
    end
  end

  defp dice_spec(%{"dice" => dice, "sides" => sides} = captures) do
    dice = String.to_integer(dice)
    {keep, from} = selection(dice, captures)

    Spec.new(dice: dice, sides: String.to_integer(sides), keep: keep, from: from)
  end

  # No selector: every die counts.
  defp selection(dice, %{"kn" => "", "dn" => ""}), do: {dice, :high}

  # Keep, defaulting to the high end when no direction is given.
  defp selection(_dice, %{"kn" => count, "kdir" => direction}) when count != "" do
    {String.to_integer(count), direction(direction, :high)}
  end

  # Drop is keeping from the opposite end: drop the lowest 1 of 4d6 is keep the
  # highest 3, drop the highest 1 is keep the lowest 3.
  defp selection(dice, %{"dn" => count, "ddir" => direction}) do
    dropped = String.to_integer(count)
    {dice - dropped, direction(direction, :low) |> opposite()}
  end

  defp direction(letter, _default) when letter in ["l", "L"], do: :low
  defp direction(letter, _default) when letter in ["h", "H"], do: :high
  defp direction(_letter, default), do: default

  defp opposite(:low), do: :high
  defp opposite(:high), do: :low

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
