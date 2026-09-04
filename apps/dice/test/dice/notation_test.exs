defmodule Dice.NotationTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Dice.Notation

  alias Dice.{Expr, Notation, Spec}

  # Notation round-trips, so rendering what was parsed is the clearest assertion.
  defp rendered(text) do
    {:ok, expr} = Notation.parse(text)
    Expr.notation(expr)
  end

  defp only_spec(text) do
    {:ok, expr} = Notation.parse(text)
    [spec] = Expr.specs(expr)
    spec
  end

  describe "parse/1 single group" do
    test "parses dice, sides, keep and modifier" do
      assert rendered("4d6k3+2") == "4D6K3+2"
      assert %Spec{dice: 4, sides: 6, keep: 3, from: :high} = only_spec("4d6k3+2")
    end

    test "keep defaults to the dice count" do
      assert %Spec{dice: 3, sides: 6, keep: 3} = only_spec("3d6")
      assert rendered("3d6") == "3D6"
    end

    test "is case insensitive" do
      assert rendered("4D6K3") == rendered("4d6k3")
      assert rendered("2D20KL1") == rendered("2d20kl1")
    end

    test "accepts every operator" do
      assert rendered("1d20+4") == "1D20+4"
      assert rendered("1d20-1") == "1D20-1"
      assert rendered("1d20*2") == "1D20*2"
    end

    test "tolerates whitespace anywhere" do
      assert rendered("  3d6 + 2  ") == "3D6+2"
      assert rendered("2d6 + 1d8") == "2D6+1D8"
    end
  end

  describe "parse/1 keep and drop selectors" do
    test "k defaults to keeping the highest" do
      assert %Spec{keep: 3, from: :high} = only_spec("4d6k3")
      assert rendered("4d6k3") == "4D6K3"
    end

    test "kh keeps the highest explicitly" do
      assert %Spec{keep: 3, from: :high} = only_spec("4d6kh3")
      assert rendered("4d6kh3") == "4D6K3"
    end

    test "kl keeps the lowest, which is how disadvantage is written" do
      assert %Spec{dice: 2, sides: 20, keep: 1, from: :low} = only_spec("2d20kl1")
      assert rendered("2d20kl1") == "2D20KL1"
    end

    test "dl drops the lowest, which is keeping the highest of the rest" do
      assert %Spec{dice: 4, keep: 3, from: :high} = only_spec("4d6dl1")
      assert rendered("4d6dl1") == "4D6K3"
    end

    test "dh drops the highest, which is keeping the lowest of the rest" do
      assert %Spec{dice: 4, keep: 3, from: :low} = only_spec("4d6dh1")
      assert rendered("4d6dh1") == "4D6KL3"
    end

    test "dropping every die is rejected with the keep message" do
      assert Notation.parse("4d6dl4") == {:error, "keep must be greater than 0."}
    end

    test "a bare d selector is rejected, since d already separates dice and sides" do
      assert {:error, _} = Notation.parse("4d6d1")
    end

    test "keeping every die renders without a keep clause" do
      assert rendered("4d6k4") == "4D6"
      assert rendered("4d6kl4") == "4D6"
    end
  end

  describe "parse/1 multiple groups" do
    test "sums two dice groups" do
      assert rendered("2d6+1d8") == "2D6+1D8"

      assert [%Spec{dice: 2, sides: 6}, %Spec{dice: 1, sides: 8}] =
               Expr.specs(elem(Notation.parse("2d6+1d8"), 1))
    end

    test "subtracts a group" do
      assert rendered("2d6-1d4") == "2D6-1D4"
    end

    test "mixes groups and constants" do
      assert rendered("2d6+1d8-1") == "2D6+1D8-1"
      assert rendered("1d20+2d6+3") == "1D20+2D6+3"
    end

    test "carries selectors through each group" do
      assert rendered("4d6k3+2d20kl1") == "4D6K3+2D20KL1"
    end

    test "a trailing multiplier scales the whole expression" do
      {:ok, expr} = Notation.parse("2d6+3*2")
      assert expr.scale == 2
      assert Expr.notation(expr) == "2D6+3*2"
    end

    test "a multiplier that is not last is rejected" do
      assert {:error, message} = Notation.parse("2d6*2+3")
      assert message =~ "must come last"
    end
  end

  describe "parse/1 rejection" do
    test "rejects malformed notation" do
      for bad <- ["d20", "4d", "4x6", "", "4d6k", "abc", "2d6+", "+", "4d6kx3"] do
        assert {:error, _} = Notation.parse(bad), "expected #{inspect(bad)} to fail"
      end
    end

    test "propagates spec validation errors" do
      assert Notation.parse("2d6k5") == {:error, "dice must be greater than or equal to keep."}
      assert Notation.parse("2d0") == {:error, "sides must be greater than 0."}
      assert Notation.parse("0d6") == {:error, "dice must be greater than 0."}
    end
  end

  describe "round trip" do
    property "rendering a parsed expression reproduces its canonical form" do
      check all(
              dice <- integer(1..50),
              sides <- integer(1..100),
              keep <- integer(1..dice),
              dir <- member_of(["", "h", "l"]),
              op <- member_of(["+", "-", "*"]),
              amount <- integer(0..20)
            ) do
        keep_part = if keep == dice, do: "", else: "k#{dir}#{keep}"
        mod_part = if op == "+" and amount == 0, do: "", else: "#{op}#{amount}"
        text = "#{dice}d#{sides}#{keep_part}#{mod_part}"

        assert {:ok, expr} = Notation.parse(text)
        # Reparsing the rendered form must land on the same expression.
        assert {:ok, ^expr} = Notation.parse(Expr.notation(expr))
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

    test "rejects a modifier that is not a number" do
      assert {:error, _} = Notation.parse_modifier("+x")
      assert {:error, _} = Notation.parse_modifier("")
      assert {:error, _} = Notation.parse_modifier("3.5")
    end
  end
end
