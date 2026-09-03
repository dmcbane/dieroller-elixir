defmodule Dice.NotationTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Dice.Notation

  alias Dice.{Notation, Spec}

  describe "parse/1" do
    test "parses the full grammar" do
      assert {:ok, %Spec{dice: 4, sides: 6, keep: 3, op: :+, amount: 2}} =
               Notation.parse("4d6k3+2")
    end

    test "keep defaults to the dice count" do
      assert {:ok, %Spec{dice: 3, sides: 6, keep: 3}} = Notation.parse("3d6")
    end

    test "is case insensitive on d and k" do
      assert Notation.parse("4D6K3") == Notation.parse("4d6k3")
    end

    test "accepts every operator" do
      assert {:ok, %Spec{op: :-, amount: 1}} = Notation.parse("1d20-1")
      assert {:ok, %Spec{op: :*, amount: 2}} = Notation.parse("1d20*2")
    end

    test "tolerates whitespace around the modifier and the whole string" do
      assert {:ok, %Spec{op: :+, amount: 2}} = Notation.parse("  3d6 + 2  ")
    end

    test "rejects malformed notation" do
      for bad <- ["d20", "4d", "4x6", "", "4d6k", "abc"] do
        assert {:error, _} = Notation.parse(bad), "expected #{inspect(bad)} to fail"
      end
    end

    test "propagates spec validation errors" do
      assert {:error, "dice must be greater than or equal to keep."} = Notation.parse("2d6k5")
      assert {:error, "sides must be greater than 0."} = Notation.parse("2d0")
    end

    property "notation survives a parse/render round trip" do
      check all(
              dice <- integer(1..50),
              sides <- integer(1..100),
              keep <- integer(1..dice),
              op <- member_of(["+", "-", "*"]),
              amount <- integer(0..20)
            ) do
        keep_part = if keep == dice, do: "", else: "k#{keep}"
        mod_part = if op == "+" and amount == 0, do: "", else: "#{op}#{amount}"
        text = "#{dice}d#{sides}#{keep_part}#{mod_part}"

        assert {:ok, spec} = Notation.parse(text)
        assert Spec.notation(spec) == String.upcase(text)
      end
    end
  end

  describe "parse_modifier/1" do
    test "reads an explicit sign" do
      assert Notation.parse_modifier("+3") == {:ok, {:+, 3}}
      assert Notation.parse_modifier("-3") == {:ok, {:-, 3}}
      assert Notation.parse_modifier("*3") == {:ok, {:*, 3}}
    end

    test "assumes addition when the sign is missing" do
      assert Notation.parse_modifier("6") == {:ok, {:+, 6}}
    end

    test "treats the default '0' as a no-op addition" do
      assert Notation.parse_modifier("0") == {:ok, {:+, 0}}
    end

    test "tolerates surrounding whitespace" do
      assert Notation.parse_modifier("  + 3 ") == {:ok, {:+, 3}}
    end

    test "rejects a modifier that is not a number" do
      assert {:error, _} = Notation.parse_modifier("+x")
      assert {:error, _} = Notation.parse_modifier("")
      assert {:error, _} = Notation.parse_modifier("3.5")
    end
  end
end
