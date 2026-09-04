defmodule Dice.AggregateTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Dice.Aggregate

  alias Dice.Aggregate

  describe "parse/1" do
    test "accepts every alias of every kind" do
      for name <- ~w(sum total), do: assert(Aggregate.parse(name) == {:ok, :sum})
      for name <- ~w(avg average mean), do: assert(Aggregate.parse(name) == {:ok, :avg})
      for name <- ~w(high highest max), do: assert(Aggregate.parse(name) == {:ok, :high})
      for name <- ~w(low lowest min), do: assert(Aggregate.parse(name) == {:ok, :low})
      for name <- ~w(median med), do: assert(Aggregate.parse(name) == {:ok, :median})
    end

    test "is case insensitive" do
      assert Aggregate.parse("SUM") == Aggregate.parse("sum")
      assert Aggregate.parse("Median") == {:ok, :median}
    end

    test "rejects anything else" do
      for bad <- ~w(worst best sums s), do: assert(Aggregate.parse(bad) == :error)
    end
  end

  describe "notation/1" do
    test "renders every alias under one canonical name" do
      assert Aggregate.notation(:sum) == "SUM"
      assert Aggregate.notation(:avg) == "AVG"
      assert Aggregate.notation(:high) == "HIGH"
      assert Aggregate.notation(:low) == "LOW"
      assert Aggregate.notation(:median) == "MEDIAN"
    end

    test "names every kind it can parse" do
      for name <- Aggregate.names() do
        assert {:ok, kind} = Aggregate.parse(name)
        assert Aggregate.notation(kind) == String.upcase(name)
      end
    end
  end

  describe "reduce/2" do
    test "sums" do
      assert Aggregate.reduce(:sum, [14, 12, 3]) == 29
    end

    test "averages, exactly" do
      assert Aggregate.reduce(:avg, [14, 12, 3]) == 29 / 3
      assert Aggregate.reduce(:avg, [4, 2]) == 3.0
    end

    test "takes the best and the worst" do
      assert Aggregate.reduce(:high, [14, 12, 3]) == 14
      assert Aggregate.reduce(:low, [14, 12, 3]) == 3
    end

    test "takes the middle of an odd number of rolls" do
      assert Aggregate.reduce(:median, [14, 12, 3]) == 12
    end

    test "splits the difference on an even number of rolls" do
      assert Aggregate.reduce(:median, [14, 12, 3, 1]) == 7.5
    end

    test "does not care what order the rolls arrived in" do
      rolls = [5, 1, 9, 3]
      shuffled = [3, 9, 1, 5]

      for kind <- [:sum, :avg, :high, :low, :median] do
        assert Aggregate.reduce(kind, rolls) == Aggregate.reduce(kind, shuffled)
      end
    end

    test "a single roll is its own aggregate" do
      for kind <- [:sum, :avg, :high, :low, :median] do
        assert Aggregate.reduce(kind, [13]) in [13, 13.0]
      end
    end

    property "every aggregate lands between the worst and the best roll" do
      check all(rolls <- list_of(integer(-50..50), min_length: 1)) do
        for kind <- [:avg, :high, :low, :median] do
          value = Aggregate.reduce(kind, rolls)
          assert value >= Enum.min(rolls)
          assert value <= Enum.max(rolls)
        end
      end
    end
  end

  describe "format/2" do
    test "prints a whole result without a decimal point" do
      assert Aggregate.format(:sum, [40, 31]) == "71"
      assert Aggregate.format(:avg, [12, 12]) == "12"
      assert Aggregate.format(:median, [11, 13]) == "12"
    end

    test "rounds a fractional result to two places" do
      assert Aggregate.format(:avg, [14, 12, 3]) == "9.67"
      assert Aggregate.format(:median, [14, 11]) == "12.5"
    end

    test "keeps a leading zero in the second place" do
      assert Aggregate.format(:avg, [1, 0, 0, 0]) == "0.25"
      assert Aggregate.format(:avg, [101, 100, 100, 100]) == "100.25"
    end

    test "rounds a half away from zero rather than toward even" do
      # 3/40 is exactly 0.075. The nearest double is a hair below it, so
      # rounding the float would give 0.07; rounding in hundredths does not.
      assert Aggregate.format(:avg, [3 | List.duplicate(0, 39)]) == "0.08"
      assert Aggregate.format(:avg, [7 | List.duplicate(0, 39)]) == "0.18"
    end

    test "handles a negative aggregate the same way" do
      assert Aggregate.format(:avg, [-3 | List.duplicate(0, 39)]) == "-0.08"
      assert Aggregate.format(:sum, [-4, -1]) == "-5"
      assert Aggregate.format(:median, [-14, -11]) == "-12.5"
    end

    property "a rounded average is never more than half a hundredth off" do
      check all(totals <- list_of(integer(-100..100), min_length: 1)) do
        exact = Enum.sum(totals) / length(totals)
        shown = String.to_float(pad(Aggregate.format(:avg, totals)))

        assert abs(shown - exact) <= 0.005 + 1.0e-9
      end
    end
  end

  # String.to_float insists on a decimal point, which a whole result omits.
  defp pad(text), do: if(String.contains?(text, "."), do: text, else: text <> ".0")
end
