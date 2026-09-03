defmodule Dice.Combinations do
  @moduledoc """
  Combinations with repetition (multisets).

  The Racket original built its ability-score tables with six nested loops and
  deduplicated the results into a set, doing 12^6 = 2,985,984 iterations to
  arrive at 12,376 distinct sets. Enumerating the multisets directly produces
  exactly those 12,376 with no duplicates to discard.
  """

  @doc """
  A lazy stream of every `k`-element multiset drawn from `pool`.

  Each result preserves the ordering of `pool`, so a descending pool yields
  descending combinations.

      iex> Dice.Combinations.stream([3, 2, 1], 2) |> Enum.to_list()
      [[3, 3], [3, 2], [3, 1], [2, 2], [2, 1], [1, 1]]
  """
  @spec stream([term()], non_neg_integer()) :: Enumerable.t()
  def stream(_pool, 0), do: Stream.concat([[[]]])
  def stream([], k) when k > 0, do: Stream.concat([[]])

  def stream(pool, k) when k > 0 do
    items = List.to_tuple(pool)
    highest = tuple_size(items) - 1

    # Walks non-decreasing index tuples like an odometer: O(k) work and constant
    # memory per element, so taking the first few of an enormous space is cheap.
    Stream.unfold(List.duplicate(0, k), fn
      nil -> nil
      indices -> {Enum.map(indices, &elem(items, &1)), advance(indices, highest)}
    end)
  end

  # Increments the rightmost index that is not yet saturated, then resets every
  # index to its right to that same value to keep the tuple non-decreasing.
  defp advance(indices, highest) do
    case indices |> Enum.reverse() |> Enum.split_while(&(&1 == highest)) do
      {_all_saturated, []} ->
        nil

      {saturated, [rightmost | leading_reversed]} ->
        next = rightmost + 1
        Enum.reverse(leading_reversed) ++ List.duplicate(next, length(saturated) + 1)
    end
  end

  @doc """
  Eager form of `stream/2`.

      iex> Dice.Combinations.with_repetition([2, 1], 2)
      [[2, 2], [2, 1], [1, 1]]
  """
  @spec with_repetition([term()], non_neg_integer()) :: [[term()]]
  def with_repetition(pool, k), do: pool |> stream(k) |> Enum.to_list()

  @doc """
  How many `k`-element multisets a pool of `n` items yields: C(n + k - 1, k).

      iex> Dice.Combinations.count(12, 6)
      12376
  """
  @spec count(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def count(n, k), do: binomial(n + k - 1, k)

  defp binomial(_n, 0), do: 1
  defp binomial(n, k) when k > n, do: 0

  defp binomial(n, k) do
    Enum.reduce(1..k, 1, fn i, acc -> div(acc * (n - k + i), i) end)
  end
end
