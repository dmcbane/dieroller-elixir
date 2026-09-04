defmodule Dice.BatchTest do
  use ExUnit.Case, async: true

  doctest Dice.Batch

  alias Dice.{Batch, Notation}

  defp notation(text) do
    {:ok, batch} = Notation.parse_roll(text)
    Batch.notation(batch)
  end

  describe "notation/1" do
    test "leaves an un-aggregated roll describing one roll" do
      assert notation("4d6k3") == "4D6K3"
      assert notation("6x4d6k3") == "4D6K3"
    end

    test "shows the repeat count once an aggregate depends on it" do
      assert notation("sum(6x4d6k3)") == "SUM(6x4D6K3)"
      assert notation("avg:100x1d20") == "AVG(100x1D20)"
    end

    test "spells the repeat out even when it is one" do
      assert notation("sum(4d6k3)") == "SUM(1x4D6K3)"
    end

    test "canonicalises the aggregate and the expression together" do
      assert notation("MAX(2X4d6dl1)") == "HIGH(2x4D6K3)"
    end
  end
end
