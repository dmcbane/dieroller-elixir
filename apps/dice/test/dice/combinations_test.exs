defmodule Dice.CombinationsTest do
  use ExUnit.Case, async: true
  doctest Dice.Combinations

  alias Dice.Combinations

  test "enumerates the closed-form count" do
    for n <- 1..8, k <- 0..5 do
      pool = Enum.to_list(1..n)
      assert length(Combinations.with_repetition(pool, k)) == Combinations.count(n, k)
    end
  end

  test "produces no duplicates" do
    result = Combinations.with_repetition(Enum.to_list(1..6), 4)
    assert Enum.uniq(result) == result
  end

  test "preserves pool ordering within each combination" do
    for combo <- Combinations.with_repetition(Enum.to_list(18..7//-1), 3) do
      assert combo == Enum.sort(combo, :desc)
    end
  end

  test "the ability-score case yields C(17, 6)" do
    assert Combinations.count(12, 6) == 12_376
  end

  test "stream/2 is lazy enough to take from an enormous space" do
    # C(50, 6) = 15,890,700 combinations; taking 3 must not build them all.
    first = Combinations.stream(Enum.to_list(45..1//-1), 6) |> Enum.take(3)
    assert first == [[45, 45, 45, 45, 45, 45], [45, 45, 45, 45, 45, 44], [45, 45, 45, 45, 45, 43]]
  end

  test "k of zero yields one empty combination" do
    assert Combinations.with_repetition([1, 2, 3], 0) == [[]]
  end

  test "an empty pool yields nothing" do
    assert Combinations.with_repetition([], 3) == []
  end
end
