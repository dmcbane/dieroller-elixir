defmodule Dice.Pathfinder.Purchase do
  @moduledoc """
  The purchase (point buy) method.

  Every legal ability spread -- six scores drawn from 7..18 -- is enumerated at
  compile time and grouped by total cost, so selecting a character at runtime is
  a map lookup plus `Enum.random/1`. The Racket original recomputed this with a
  memoized 12^6 brute force on first use.
  """

  alias Dice.Combinations
  alias Dice.Pathfinder.Tables

  @campaigns %{low: 10, standard: 15, high: 20, epic: 25}

  # Evaluated by the compiler and baked into the BEAM file as a literal.
  @by_cost Combinations.stream(Enum.to_list(18..7//-1), 6)
           |> Enum.group_by(&Tables.total_cost/1)
           |> Map.new(fn {cost, spreads} -> {cost, spreads} end)

  @set_count @by_cost |> Map.values() |> Enum.map(&length/1) |> Enum.sum()

  @doc """
  Every legal spread, grouped by total purchase cost.

  Referenced once so the literal lives in the constant pool rather than being
  inlined at each call site.
  """
  @spec by_cost() :: %{integer() => [[pos_integer()]]}
  def by_cost, do: @by_cost

  @doc """
  How many distinct legal spreads exist: C(17, 6).

      iex> Dice.Pathfinder.Purchase.set_count()
      12376
  """
  @spec set_count() :: pos_integer()
  def set_count, do: @set_count

  @doc """
  Purchase points granted by each campaign type.

      iex> Dice.Pathfinder.Purchase.campaign_points(:epic)
      25
  """
  @spec campaign_points(atom()) :: pos_integer() | nil
  def campaign_points(campaign), do: Map.get(@campaigns, campaign)

  @doc """
  Parses a campaign type by first letter, as the original did.

      iex> Dice.Pathfinder.Purchase.parse_campaign("Epic Fantasy")
      {:ok, :epic}

      iex> Dice.Pathfinder.Purchase.parse_campaign("s")
      {:ok, :standard}
  """
  @spec parse_campaign(String.t()) :: {:ok, atom()} | {:error, String.t()}
  def parse_campaign(string) do
    case string |> String.trim() |> String.upcase() do
      "E" <> _ -> {:ok, :epic}
      "H" <> _ -> {:ok, :high}
      "S" <> _ -> {:ok, :standard}
      "L" <> _ -> {:ok, :low}
      _ -> {:error, "purchase type must be one of low, standard, high, or epic."}
    end
  end

  @doc """
  Spreads that cost exactly `points`.

  Exact equality matches the original: a 15-point character spends all 15.
  """
  @spec spreads_for(integer()) :: [[pos_integer()]]
  def spreads_for(points), do: Map.get(@by_cost, points, [])

  @doc "Picks a random spread costing exactly `points`, sorted descending."
  @spec generate(integer()) :: {:ok, [pos_integer()]} | {:error, String.t()}
  def generate(points) do
    case spreads_for(points) do
      [] -> {:error, "no legal ability spread costs exactly #{points} points."}
      spreads -> {:ok, Enum.random(spreads)}
    end
  end
end
