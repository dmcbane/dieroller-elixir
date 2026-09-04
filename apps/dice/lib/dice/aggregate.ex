defmodule Dice.Aggregate do
  @moduledoc """
  Reducing the repeated rolls of one expression to a single number.

  `6x4d6k3` produces six independent totals and reports them one by one. An
  aggregate says what to do with the six instead: `sum(6x4d6k3)` adds them up,
  `avg(6x4d6k3)` averages them, `high(6x4d6k3)` reports the best of them.

  Each kind answers to several names, so the notation can read the way the
  roller thinks of it -- `max` and `high` are one aggregate -- and each renders
  under a single canonical name, the way `kh` renders as `K`.

  `:sum`, `:high`, `:low` and an odd-length `:median` are whole numbers; `:avg`
  and an even-length `:median` are not, so `reduce/2` returns a number of either
  kind and `format/2` decides how it prints.
  """

  # Canonical name first: it is the one notation/1 renders and the one the
  # error message for an unknown aggregate offers.
  @kinds [
    sum: ~w(sum total),
    avg: ~w(avg average mean),
    high: ~w(high highest max),
    low: ~w(low lowest min),
    median: ~w(median med)
  ]

  @by_name for {kind, names} <- @kinds, name <- names, into: %{}, do: {name, kind}
  @canonical for {kind, [name | _]} <- @kinds, into: %{}, do: {kind, name}
  @names for {_kind, [name | _]} <- @kinds, do: name

  @type t :: :sum | :avg | :high | :low | :median

  @doc """
  Looks up an aggregate by any of its names, case-insensitively.

      iex> Dice.Aggregate.parse("sum")
      {:ok, :sum}

      iex> Dice.Aggregate.parse("MAX")
      {:ok, :high}

      iex> Dice.Aggregate.parse("nonesuch")
      :error
  """
  @spec parse(String.t()) :: {:ok, t()} | :error
  def parse(name), do: Map.fetch(@by_name, String.downcase(name))

  @doc """
  The canonical name of every aggregate, in the order they are documented.

      iex> Dice.Aggregate.names()
      ["sum", "avg", "high", "low", "median"]
  """
  @spec names() :: [String.t()]
  def names, do: @names

  @doc """
  Renders an aggregate in canonical notation.

      iex> Dice.Aggregate.notation(:high)
      "HIGH"
  """
  @spec notation(t()) :: String.t()
  def notation(kind), do: @canonical |> Map.fetch!(kind) |> String.upcase()

  @doc """
  Reduces the totals of a batch of rolls to the aggregate's single value.

      iex> Dice.Aggregate.reduce(:sum, [3, 1, 2])
      6

      iex> Dice.Aggregate.reduce(:avg, [3, 1, 2])
      2.0

      iex> Dice.Aggregate.reduce(:median, [3, 1, 2])
      2

      iex> Dice.Aggregate.reduce(:median, [4, 1, 2, 3])
      2.5
  """
  @spec reduce(t(), [integer(), ...]) :: number()
  def reduce(:sum, totals), do: Enum.sum(totals)
  def reduce(:avg, totals), do: Enum.sum(totals) / length(totals)
  def reduce(:high, totals), do: Enum.max(totals)
  def reduce(:low, totals), do: Enum.min(totals)

  def reduce(:median, totals) do
    sorted = Enum.sort(totals)
    middle = div(length(totals), 2)

    case rem(length(totals), 2) do
      1 -> Enum.at(sorted, middle)
      0 -> (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
    end
  end

  @doc """
  Renders the aggregate of `totals` for display.

  A fractional result is rounded to two places, which keeps an average legible
  without claiming a precision the dice do not have. A result that is whole
  after that rounding prints as a whole number: the median of six rolls is
  often exactly 12, and `12.0` reads like a defect.

  This takes the totals rather than the value `reduce/2` produced because the
  rounding is done in whole numbers. The average of forty rolls totalling three
  is exactly 0.075, which rounds to 0.08 -- but the nearest double to 0.075 is
  a hair below it, so rounding the float gives 0.07 instead. Working in
  hundredths keeps the answer independent of that, and keeps it identical to
  the Racket implementation's, which uses exact rationals.

  Only the display rounds. `reduce/2` returns the exact value, which is what
  `--json` reports.

      iex> Dice.Aggregate.format(:sum, [40, 31])
      "71"

      iex> Dice.Aggregate.format(:median, [14, 11])
      "12.5"

      iex> Dice.Aggregate.format(:avg, [14, 12, 3, 16, 10, 12])
      "11.17"

      iex> Dice.Aggregate.format(:avg, [12, 12])
      "12"

      iex> Dice.Aggregate.format(:avg, [3, 0, 0, 0])
      "0.75"
  """
  @spec format(t(), [integer(), ...]) :: String.t()
  def format(kind, totals), do: kind |> hundredths(totals) |> decimal()

  # An average is rounded here rather than by scaling a float, for the reason
  # given above.
  defp hundredths(:avg, totals), do: round_hundredths(Enum.sum(totals), length(totals))

  # Every other aggregate is a whole number or an exact half, and a float holds
  # both of those exactly, so scaling the reduced value loses nothing.
  defp hundredths(kind, totals), do: round(reduce(kind, totals) * 100)

  # Half away from zero, which is how a person rounds by hand.
  defp round_hundredths(sum, count) when sum >= 0, do: div(sum * 200 + count, count * 2)
  defp round_hundredths(sum, count), do: -div(-sum * 200 + count, count * 2)

  defp decimal(hundredths) when rem(hundredths, 100) == 0 do
    hundredths |> div(100) |> Integer.to_string()
  end

  defp decimal(hundredths) do
    sign = if hundredths < 0, do: "-", else: ""
    magnitude = abs(hundredths)

    places =
      magnitude
      |> rem(100)
      |> Integer.to_string()
      |> String.pad_leading(2, "0")
      |> String.trim_trailing("0")

    "#{sign}#{div(magnitude, 100)}.#{places}"
  end
end
