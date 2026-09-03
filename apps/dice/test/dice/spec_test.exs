defmodule Dice.SpecTest do
  use ExUnit.Case, async: true
  doctest Dice.Spec

  alias Dice.Spec

  describe "new/1" do
    test "keep defaults to the number of dice" do
      assert {:ok, %Spec{dice: 5, keep: 5}} = Spec.new(dice: 5)
    end

    test "defaults match the original CLI: 1d20, no modifier" do
      assert {:ok, %Spec{dice: 1, sides: 20, keep: 1, op: :+, amount: 0}} = Spec.new()
    end

    # These messages are carried over verbatim from the Racket implementation.
    test "rejects invalid input with the original messages" do
      assert {:error, "dice must be greater than 0."} = Spec.new(dice: 0)
      assert {:error, "keep must be greater than 0."} = Spec.new(dice: 3, keep: 0)
      assert {:error, "dice must be greater than or equal to keep."} = Spec.new(dice: 3, keep: 4)
      assert {:error, "sides must be greater than 0."} = Spec.new(dice: 3, sides: 0)
    end

    test "reports the first failure in the original's check order" do
      # Both dice and sides are invalid; the original reported dice first.
      assert {:error, "dice must be greater than 0."} = Spec.new(dice: 0, sides: 0)
    end
  end

  describe "notation/1" do
    test "omits the keep clause when every die is kept" do
      assert notation(dice: 3, sides: 6) == "3D6"
    end

    test "includes the keep clause when dice are dropped" do
      assert notation(dice: 4, sides: 6, keep: 3) == "4D6K3"
    end

    test "omits only an exactly-zero addition" do
      assert notation(dice: 3, sides: 6, op: :+, amount: 0) == "3D6"
      assert notation(dice: 3, sides: 6, op: :-, amount: 0) == "3D6-0"
      assert notation(dice: 3, sides: 6, op: :*, amount: 0) == "3D6*0"
    end

    test "renders every operator" do
      assert notation(dice: 1, sides: 20, op: :+, amount: 4) == "1D20+4"
      assert notation(dice: 1, sides: 20, op: :-, amount: 1) == "1D20-1"
      assert notation(dice: 1, sides: 20, op: :*, amount: 2) == "1D20*2"
    end

    test "combines keep and modifier" do
      assert notation(dice: 5, sides: 100, keep: 3, op: :+, amount: 4) == "5D100K3+4"
    end

    defp notation(fields) do
      {:ok, spec} = Spec.new(fields)
      Spec.notation(spec)
    end
  end

  describe "apply_modifier/2" do
    test "applies to the kept sum, not to each die" do
      {:ok, spec} = Spec.new(dice: 3, sides: 6, op: :*, amount: 2)
      assert Spec.apply_modifier(spec, 9) == 18
    end

    test "subtraction may drive a result negative" do
      {:ok, spec} = Spec.new(dice: 1, sides: 6, op: :-, amount: 10)
      assert Spec.apply_modifier(spec, 3) == -7
    end
  end
end
