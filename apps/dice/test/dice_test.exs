defmodule DiceTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Dice

  alias Dice.Spec

  # Generates only specs that Spec.new/1 accepts, so properties never have to
  # filter out invalid input.
  defp valid_spec do
    gen all(
          dice <- integer(1..30),
          sides <- integer(1..100),
          keep <- integer(1..dice),
          op <- member_of([:+, :-, :*]),
          amount <- integer(0..20)
        ) do
      {:ok, spec} = Spec.new(dice: dice, sides: sides, keep: keep, op: op, amount: amount)
      spec
    end
  end

  describe "roll/1" do
    property "rolls exactly `dice` dice and keeps exactly `keep` of them" do
      check all(spec <- valid_spec()) do
        roll = Dice.roll(spec)
        assert length(roll.rolled) == spec.dice
        assert length(roll.kept) == spec.keep
      end
    end

    property "every die lands within 1..sides" do
      check all(spec <- valid_spec()) do
        assert Enum.all?(Dice.roll(spec).rolled, &(&1 >= 1 and &1 <= spec.sides))
      end
    end

    property "kept holds the highest rolls, in descending order" do
      check all(spec <- valid_spec()) do
        roll = Dice.roll(spec)
        assert roll.kept == roll.rolled |> Enum.sort(:desc) |> Enum.take(spec.keep)
        assert roll.kept == Enum.sort(roll.kept, :desc)
      end
    end

    property "subtotal sums the kept dice and total applies the modifier to it" do
      check all(spec <- valid_spec()) do
        roll = Dice.roll(spec)
        assert roll.subtotal == Enum.sum(roll.kept)
        assert roll.total == Spec.apply_modifier(spec, roll.subtotal)
      end
    end

    test "a single-sided die is deterministic" do
      {:ok, spec} = Spec.new(dice: 5, sides: 1)
      roll = Dice.roll(spec)
      assert roll.rolled == [1, 1, 1, 1, 1]
      assert roll.total == 5
    end

    test "the modifier multiplies the whole kept total, not each die" do
      {:ok, spec} = Spec.new(dice: 3, sides: 1, op: :*, amount: 2)
      assert Dice.roll(spec).total == 6
    end
  end

  describe "stream/1" do
    test "is lazy and yields one roll per element" do
      {:ok, spec} = Spec.new(dice: 2, sides: 6)
      rolls = spec |> Dice.stream() |> Enum.take(4)
      assert length(rolls) == 4
      assert Enum.all?(rolls, &(length(&1.rolled) == 2))
    end
  end

  describe "seed/1" do
    test "the same seed reproduces the same rolls" do
      {:ok, spec} = Spec.new(dice: 10, sides: 100)

      Dice.seed(42)
      first = spec |> Dice.stream() |> Enum.take(5)
      Dice.seed(42)
      assert spec |> Dice.stream() |> Enum.take(5) == first
    end

    test "different seeds diverge" do
      {:ok, spec} = Spec.new(dice: 20, sides: 1000)

      Dice.seed(1)
      first = Dice.roll(spec).rolled
      Dice.seed(2)
      refute Dice.roll(spec).rolled == first
    end
  end
end
