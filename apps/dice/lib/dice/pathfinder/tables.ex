defmodule Dice.Pathfinder.Tables do
  @moduledoc """
  Ability score lookup tables.

  Scores 1..6 and 19..45 are not legal purchase values in Pathfinder; they are
  extrapolations of the published table, kept so that rolled characters (which
  can fall outside the purchase range) can still be priced and compared.
  """

  # {score, purchase cost, ability bonus} -- transcribed from the Racket source
  # so the two tables stay aligned and remain diffable against the original.
  @table [
    {1, -25, -5},
    {2, -20, -4},
    {3, -16, -4},
    {4, -12, -3},
    {5, -9, -3},
    {6, -6, -2},
    {7, -4, -2},
    {8, -2, -1},
    {9, -1, -1},
    {10, 0, 0},
    {11, 1, 0},
    {12, 2, 1},
    {13, 3, 1},
    {14, 5, 2},
    {15, 7, 2},
    {16, 10, 3},
    {17, 13, 3},
    {18, 17, 4},
    {19, 21, 4},
    {20, 26, 5},
    {21, 31, 5},
    {22, 37, 6},
    {23, 43, 6},
    {24, 50, 7},
    {25, 57, 7},
    {26, 65, 8},
    {27, 73, 8},
    {28, 82, 9},
    {29, 91, 9},
    {30, 101, 10},
    {31, 111, 10},
    {32, 122, 11},
    {33, 133, 11},
    {34, 145, 12},
    {35, 157, 12},
    {36, 170, 13},
    {37, 183, 13},
    {38, 197, 14},
    {39, 211, 14},
    {40, 226, 15},
    {41, 241, 15},
    {42, 257, 16},
    {43, 273, 16},
    {44, 290, 17},
    {45, 307, 17}
  ]

  @doc "The full table as `{score, cost, bonus}` tuples."
  @spec table() :: [{pos_integer(), integer(), integer()}]
  def table, do: @table

  @doc "The range of scores the tables cover."
  @spec scores() :: Range.t()
  def scores, do: 1..45

  @doc "Scores that are legal to buy with purchase points."
  @spec legal_scores() :: Range.t()
  def legal_scores, do: 7..18

  # One function clause per score compiles to a jump table, so lookups need no
  # map and an out-of-range score raises FunctionClauseError instead of
  # silently returning nil.
  for {score, cost, bonus} <- @table do
    @doc false
    def cost(unquote(score)), do: unquote(cost)
    @doc false
    def bonus(unquote(score)), do: unquote(bonus)
  end

  @doc """
  Total purchase cost of a set of ability scores.

      iex> Dice.Pathfinder.Tables.total_cost([15, 14, 13, 12, 10, 8])
      15
  """
  @spec total_cost([pos_integer()]) :: integer()
  def total_cost(scores), do: Enum.sum_by(scores, &cost/1)

  @doc """
  Total ability bonus of a set of ability scores.

      iex> Dice.Pathfinder.Tables.total_bonus([15, 14, 13, 12, 10, 8])
      5
  """
  @spec total_bonus([pos_integer()]) :: integer()
  def total_bonus(scores), do: Enum.sum_by(scores, &bonus/1)
end
