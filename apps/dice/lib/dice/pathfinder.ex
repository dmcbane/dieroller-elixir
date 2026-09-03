defmodule Dice.Pathfinder do
  @moduledoc """
  Pathfinder character generation.

  Five methods are supported, named as they are on the command line:

    * `:classic`  -- 3D6 per ability
    * `:standard` -- 4D6 keep the highest 3, per ability
    * `:heroic`   -- 2D6 plus 6, per ability
    * `{:pool, counts}` -- 24D6 split across the six abilities, keep 3 each
    * `{:purchase, points}` -- a random spread costing exactly `points`
  """

  alias Dice.Pathfinder.{Character, Purchase}
  alias Dice.Spec

  @pool_total 24
  @pool_minimum 3
  @abilities 6

  @type method ::
          :classic | :standard | :heroic | {:pool, [pos_integer()]} | {:purchase, integer()}

  @doc """
  Generates `count` characters, sorted ascending by total ability bonus.

  Sorting weakest-first matches the original, which put the best roll last so it
  is the line left on screen.
  """
  @spec characters(method(), pos_integer()) :: {:ok, [Character.t()]} | {:error, String.t()}
  def characters(method, count) do
    with :ok <- validate_count(count),
         {:ok, generate} <- generator(method) do
      characters =
        Enum.reduce_while(1..count//1, {:ok, []}, fn _, {:ok, acc} ->
          case generate.() do
            {:ok, abilities} -> {:cont, {:ok, [Character.new(abilities) | acc]}}
            {:error, _} = error -> {:halt, error}
          end
        end)

      with {:ok, list} <- characters do
        {:ok, Enum.sort_by(list, & &1.bonus_total)}
      end
    end
  end

  @doc "Generates a single character."
  @spec character(method()) :: {:ok, Character.t()} | {:error, String.t()}
  def character(method) do
    with {:ok, [character]} <- characters(method, 1), do: {:ok, character}
  end

  @doc """
  The per-ability dice specs a rolled method uses.

      iex> {:ok, specs} = Dice.Pathfinder.ability_specs(:standard)
      iex> specs |> hd() |> Dice.Spec.notation()
      "4D6K3"

      iex> {:ok, specs} = Dice.Pathfinder.ability_specs(:heroic)
      iex> specs |> hd() |> Dice.Spec.notation()
      "2D6+6"
  """
  @spec ability_specs(method()) :: {:ok, [Spec.t()]} | {:error, String.t()}
  def ability_specs(:classic), do: uniform_specs(dice: 3, keep: 3)
  def ability_specs(:standard), do: uniform_specs(dice: 4, keep: 3)
  def ability_specs(:heroic), do: uniform_specs(dice: 2, keep: 2, op: :+, amount: 6)

  def ability_specs({:pool, counts}) do
    with :ok <- validate_pool(counts) do
      counts
      |> Enum.map(&Spec.new(dice: &1, sides: 6, keep: @pool_minimum))
      |> collect()
    end
  end

  @doc """
  Parses a pool distribution such as `"3/3/3/3/3/9"`.

  Commas, slashes, and colons all separate, as in the original.

      iex> Dice.Pathfinder.parse_pool("3:3:4:6:4:4")
      {:ok, [3, 3, 4, 6, 4, 4]}

      iex> Dice.Pathfinder.parse_pool("3/3/3/3/3/3")
      {:error, "you must specify a total of twenty-four dice for the pool."}
  """
  @spec parse_pool(String.t()) :: {:ok, [pos_integer()]} | {:error, String.t()}
  def parse_pool(string) do
    counts =
      string |> String.split(~r/[,\/:]/, trim: true) |> Enum.map(&Integer.parse(String.trim(&1)))

    if Enum.all?(counts, &match?({_, ""}, &1)) do
      counts = Enum.map(counts, &elem(&1, 0))
      with :ok <- validate_pool(counts), do: {:ok, counts}
    else
      {:error, "dice per attribute must be numbers separated by , / or :."}
    end
  end

  @doc "The default pool distribution: four dice per ability."
  @spec default_pool() :: [pos_integer()]
  def default_pool, do: List.duplicate(4, @abilities)

  # Validation messages are carried over verbatim from the Racket original.
  defp validate_pool(counts) when length(counts) != @abilities do
    {:error, "dice per attribute must specify die quantity for six attributes."}
  end

  defp validate_pool(counts) do
    cond do
      Enum.any?(counts, &(&1 < @pool_minimum)) ->
        {:error, "a minimum of 3 dice must be used for each attribute."}

      Enum.sum(counts) != @pool_total ->
        {:error, "you must specify a total of twenty-four dice for the pool."}

      true ->
        :ok
    end
  end

  defp validate_count(count) when is_integer(count) and count > 0, do: :ok
  defp validate_count(_), do: {:error, "number of characters must be greater than 0."}

  defp generator({:purchase, points}), do: {:ok, fn -> Purchase.generate(points) end}

  defp generator(method) do
    with {:ok, specs} <- ability_specs(method) do
      {:ok, fn -> {:ok, Enum.map(specs, &Dice.roll(&1).total)} end}
    end
  end

  defp uniform_specs(fields) do
    fields
    |> Keyword.put(:sides, 6)
    |> Spec.new()
    |> case do
      {:ok, spec} -> {:ok, List.duplicate(spec, @abilities)}
      error -> error
    end
  end

  defp collect(results) do
    Enum.reduce_while(results, {:ok, []}, fn
      {:ok, value}, {:ok, acc} -> {:cont, {:ok, [value | acc]}}
      {:error, _} = error, _ -> {:halt, error}
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      error -> error
    end
  end
end
