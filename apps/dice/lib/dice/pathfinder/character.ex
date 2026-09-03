defmodule Dice.Pathfinder.Character do
  @moduledoc """
  A generated character: six ability scores plus their totals.

  Abilities are in STR, DEX, CON, INT, WIS, CHR order for the rolled methods.
  The purchase method has no roll order, so its spreads come back sorted
  descending.
  """

  alias Dice.Pathfinder.Tables

  @abbreviations ~w(STR DEX CON INT WIS CHR)

  defstruct [:abilities, :bonus_total, :cost_total]

  @type t :: %__MODULE__{
          abilities: [pos_integer()],
          bonus_total: integer(),
          cost_total: integer()
        }

  @doc "The ability abbreviations, in order."
  @spec abbreviations() :: [String.t()]
  def abbreviations, do: @abbreviations

  @doc """
  Builds a character from six ability scores, computing both totals.

      iex> Dice.Pathfinder.Character.new([15, 14, 13, 12, 10, 8])
      %Dice.Pathfinder.Character{abilities: [15, 14, 13, 12, 10, 8], bonus_total: 5, cost_total: 15}
  """
  @spec new([pos_integer()]) :: t()
  def new(abilities) when length(abilities) == 6 do
    %__MODULE__{
      abilities: abilities,
      bonus_total: Tables.total_bonus(abilities),
      cost_total: Tables.total_cost(abilities)
    }
  end

  @doc """
  Pairs each ability with its abbreviation.

      iex> Dice.Pathfinder.Character.new([15, 14, 13, 12, 10, 8]) |> Dice.Pathfinder.Character.labeled()
      [{"STR", 15}, {"DEX", 14}, {"CON", 13}, {"INT", 12}, {"WIS", 10}, {"CHR", 8}]
  """
  @spec labeled(t()) :: [{String.t(), pos_integer()}]
  def labeled(%__MODULE__{abilities: abilities}), do: Enum.zip(@abbreviations, abilities)
end
