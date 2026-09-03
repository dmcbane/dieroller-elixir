defmodule Dice.Pathfinder.TablesTest do
  use ExUnit.Case, async: true
  doctest Dice.Pathfinder.Tables

  alias Dice.Pathfinder.Tables

  test "covers scores 1..45 with no gaps" do
    assert length(Tables.table()) == 45
    assert Enum.map(Tables.table(), &elem(&1, 0)) == Enum.to_list(1..45)
  end

  test "boundary costs match the original table" do
    assert Tables.cost(1) == -25
    assert Tables.cost(10) == 0
    assert Tables.cost(18) == 17
    assert Tables.cost(45) == 307
  end

  test "boundary bonuses match the original table" do
    assert Tables.bonus(1) == -5
    assert Tables.bonus(10) == 0
    assert Tables.bonus(18) == 4
    assert Tables.bonus(45) == 17
  end

  # An independent check on the transcription: the published bonus progression
  # is floor((score - 10) / 2), so any typo in the 45 rows shows up here.
  test "every bonus follows floor((score - 10) / 2)" do
    for score <- Tables.scores() do
      assert Tables.bonus(score) == Integer.floor_div(score - 10, 2),
             "bonus(#{score}) disagrees with the published progression"
    end
  end

  test "cost rises monotonically with score" do
    costs = Enum.map(Tables.scores(), &Tables.cost/1)
    assert costs == Enum.sort(costs)
    assert Enum.uniq(costs) == costs
  end

  test "the standard array costs exactly the standard-fantasy budget" do
    assert Tables.total_cost([15, 14, 13, 12, 10, 8]) == 15
  end

  test "an out-of-range score raises rather than returning nil" do
    assert_raise FunctionClauseError, fn -> Tables.cost(0) end
    assert_raise FunctionClauseError, fn -> Tables.bonus(46) end
  end
end
