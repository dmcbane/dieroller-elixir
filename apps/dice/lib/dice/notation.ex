defmodule Dice.Notation do
  @moduledoc """
  Parsing of dice notation and of the bare modifier argument the original
  command line accepted (`+3`, `-1`, `*2`, or a lone `3`).

  The grammar is

      roll       := aggregate '(' repeated ')'
                  | aggregate ':' repeated
                  | repeated
      repeated   := (integer 'x')? expression
      aggregate  := 'sum' | 'avg' | 'high' | 'low' | 'median' | alias
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

  An aggregate wraps the whole thing and reduces those repeats to one number:
  `sum(6x4d6k3)`, `avg(100x1d20)`, `high(2x1d20)`. The parenthesised form is the
  one to reach for, but a shell will eat unquoted parentheses, so `sum:6x4d6k3`
  means exactly the same thing and needs no quoting. See `Dice.Aggregate` for
  the kinds and their aliases.

  Dropping is stored as keeping from the opposite end, so `4d6dl1` and `4d6k3`
  produce the same spec and both render as `4D6K3`.
  """

  alias Dice.{Aggregate, Batch, Expr, Spec}

  @token ~r/^([-+*])?(\d+[dD]\d+(?:[kK][hHlL]?\d+|[dD][hHlL]\d+)?|\d+)/

  @dice ~r/^(?<dice>\d+)[dD](?<sides>\d+)(?:(?<kop>[kK])(?<kdir>[hHlL]?)(?<kn>\d+)|(?<dop>[dD])(?<ddir>[hHlL])(?<dn>\d+))?$/

  @repeat ~r/^(\d+)[xX](.+)$/

  @aggregate ~r/^(?<name>[a-zA-Z]+)(?:\((?<paren>.*)\)|:(?<colon>.+))$/

  @ops %{"+" => :+, "-" => :-, "*" => :*}

  @doc """
  Parses a whole roll: an optional aggregate, an optional `<n>x` repeat count,
  then an expression.

  Unlike `parse/1` this insists the expression contain at least one dice group,
  so a bare constant is reported rather than silently rolling nothing.

      iex> {:ok, batch} = Dice.Notation.parse_roll("6x4d6k3")
      iex> {batch.repeat, batch.aggregate, Dice.Expr.notation(batch.expr)}
      {6, nil, "4D6K3"}

      iex> {:ok, batch} = Dice.Notation.parse_roll("2d6+1d8-1")
      iex> {batch.repeat, Dice.Expr.notation(batch.expr)}
      {1, "2D6+1D8-1"}

      iex> {:ok, batch} = Dice.Notation.parse_roll("sum(6x4d6k3)")
      iex> {batch.repeat, batch.aggregate}
      {6, :sum}

      iex> {:ok, batch} = Dice.Notation.parse_roll("avg:100x1d20")
      iex> {batch.repeat, batch.aggregate}
      {100, :avg}

      iex> Dice.Notation.parse_roll("0x3d6")
      {:error, "repeat count must be greater than 0."}

      iex> Dice.Notation.parse_roll("7")
      {:error, ~s(expression contains no dice: "7")}

      iex> Dice.Notation.parse_roll("worst(6x4d6k3)")
      {:error, ~s(unknown aggregate "worst"; use sum, avg, high, low, or median.)}
  """
  @spec parse_roll(String.t()) :: {:ok, Batch.t()} | {:error, String.t()}
  def parse_roll(string) do
    trimmed = String.trim(string)

    with {:ok, kind, rest} <- aggregate(strip(trimmed)),
         {:ok, repeat, rest} <- repeat(rest),
         {:ok, expr} <- parse_reported_as(rest, trimmed),
         :ok <- dice_present(expr, trimmed) do
      {:ok, %Batch{expr: expr, repeat: repeat, aggregate: kind}}
    end
  end

  # An aggregate wraps the whole roll rather than sitting inside the
  # expression, so it is peeled off before anything else is parsed. The `:`
  # spelling exists because a shell would eat unquoted parentheses.
  defp aggregate(text) do
    case Regex.named_captures(@aggregate, text) do
      nil ->
        {:ok, nil, text}

      %{"name" => name, "paren" => paren, "colon" => colon} ->
        case Aggregate.parse(name) do
          {:ok, kind} -> {:ok, kind, if(colon == "", do: paren, else: colon)}
          :error -> {:error, unknown_aggregate(name)}
        end
    end
  end

  defp unknown_aggregate(name) do
    {last, rest} = List.pop_at(Aggregate.names(), -1)
    ~s(unknown aggregate "#{name}"; use #{Enum.join(rest, ", ")}, or #{last}.)
  end

  defp repeat(text) do
    case Regex.run(@repeat, text, capture: :all_but_first) do
      nil -> {:ok, 1, text}
      [count, rest] -> counted(String.to_integer(count), rest)
    end
  end

  defp counted(count, _rest) when count < 1, do: {:error, "repeat count must be greater than 0."}
  defp counted(count, rest), do: {:ok, count, rest}

  defp dice_present(expr, original) do
    case Expr.specs(expr) do
      [] -> {:error, ~s(expression contains no dice: "#{original}")}
      _ -> :ok
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
  def parse(string), do: parse_reported_as(string, string)

  # By the time `parse_roll/1` gets here it has stripped the whitespace and
  # peeled off the aggregate and the repeat count, none of which the roller
  # wants to see quoted back at them: an error names the roll as it was written.
  defp parse_reported_as(string, original) do
    with {:ok, tokens} <- scan(strip(string), original, []) do
      build(tokens, original)
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
