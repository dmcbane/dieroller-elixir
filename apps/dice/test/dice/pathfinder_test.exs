defmodule Dice.PathfinderTest do
  use ExUnit.Case, async: true
  doctest Dice.Pathfinder

  alias Dice.Pathfinder
  alias Dice.Pathfinder.{Character, Tables}

  describe "ability_specs/1" do
    test "each method uses the dice the original documented" do
      assert notation(:classic) == "3D6"
      assert notation(:standard) == "4D6K3"
      assert notation(:heroic) == "2D6+6"

      assert notation({:pool, [3, 3, 4, 6, 4, 4]}) == [
               "3D6",
               "3D6",
               "4D6K3",
               "6D6K3",
               "4D6K3",
               "4D6K3"
             ]
    end

    test "every method produces six specs" do
      for method <- [:classic, :standard, :heroic, {:pool, [4, 4, 4, 4, 4, 4]}] do
        assert {:ok, specs} = Pathfinder.ability_specs(method)
        assert length(specs) == 6
      end
    end

    defp notation({:pool, _} = method) do
      {:ok, specs} = Pathfinder.ability_specs(method)
      Enum.map(specs, &Dice.Spec.notation/1)
    end

    defp notation(method) do
      {:ok, specs} = Pathfinder.ability_specs(method)
      specs |> hd() |> Dice.Spec.notation()
    end
  end

  describe "characters/2" do
    test "generates the requested number" do
      assert {:ok, characters} = Pathfinder.characters(:standard, 7)
      assert length(characters) == 7
    end

    test "each character has six abilities and consistent totals" do
      {:ok, characters} = Pathfinder.characters(:standard, 20)

      for character <- characters do
        assert length(character.abilities) == 6
        assert character.bonus_total == Tables.total_bonus(character.abilities)
        assert character.cost_total == Tables.total_cost(character.abilities)
      end
    end

    test "results are sorted weakest first, as the original printed them" do
      {:ok, characters} = Pathfinder.characters(:standard, 25)
      bonuses = Enum.map(characters, & &1.bonus_total)
      assert bonuses == Enum.sort(bonuses)
    end

    test "score ranges match each method's dice" do
      assert_range(:classic, 3..18)
      assert_range(:standard, 3..18)
      # 2D6 + 6 can never roll below 8, which is the point of the heroic method.
      assert_range(:heroic, 8..18)
    end

    defp assert_range(method, expected) do
      {:ok, characters} = Pathfinder.characters(method, 50)
      scores = Enum.flat_map(characters, & &1.abilities)

      assert Enum.all?(scores, &(&1 in expected)),
             "#{method} produced #{inspect(Enum.min_max(scores))}"
    end

    test "purchase characters always spend the full budget" do
      {:ok, characters} = Pathfinder.characters({:purchase, 15}, 50)
      assert Enum.all?(characters, &(&1.cost_total == 15))
    end

    test "the pool method honours its distribution" do
      # Nine dice keep three should skew that ability high.
      {:ok, characters} = Pathfinder.characters({:pool, [9, 3, 3, 3, 3, 3]}, 200)
      averages = characters |> Enum.map(& &1.abilities) |> Enum.zip_with(&(Enum.sum(&1) / 200))
      assert hd(averages) > Enum.at(averages, 1)
    end

    test "rejects a non-positive count" do
      assert Pathfinder.characters(:standard, 0) ==
               {:error, "number of characters must be greater than 0."}

      assert Pathfinder.characters(:standard, -1) ==
               {:error, "number of characters must be greater than 0."}
    end

    test "propagates pool validation errors" do
      assert {:error, message} = Pathfinder.characters({:pool, [1, 1, 1, 1, 1, 1]}, 1)
      assert message == "a minimum of 3 dice must be used for each attribute."
    end
  end

  describe "parse_pool/1" do
    test "accepts every separator the original did" do
      assert Pathfinder.parse_pool("3,3,4,6,4,4") == {:ok, [3, 3, 4, 6, 4, 4]}
      assert Pathfinder.parse_pool("3/3/4/6/4/4") == {:ok, [3, 3, 4, 6, 4, 4]}
      assert Pathfinder.parse_pool("3:3:4:6:4:4") == {:ok, [3, 3, 4, 6, 4, 4]}
    end

    test "accepts the documented example distribution" do
      assert Pathfinder.parse_pool("3/3/3/3/3/9") == {:ok, [3, 3, 3, 3, 3, 9]}
    end

    test "reports the original validation messages" do
      assert Pathfinder.parse_pool("3/3/3/3/3") ==
               {:error, "dice per attribute must specify die quantity for six attributes."}

      assert Pathfinder.parse_pool("2/3/3/3/3/10") ==
               {:error, "a minimum of 3 dice must be used for each attribute."}

      assert Pathfinder.parse_pool("3/3/3/3/3/3") ==
               {:error, "you must specify a total of twenty-four dice for the pool."}
    end

    test "rejects non-numeric entries" do
      assert {:error, message} = Pathfinder.parse_pool("3/3/x/3/3/9")
      assert message =~ "must be numbers"
    end

    test "the default pool is legal" do
      assert Pathfinder.parse_pool(Enum.join(Pathfinder.default_pool(), "/")) ==
               {:ok, [4, 4, 4, 4, 4, 4]}
    end
  end

  describe "Character" do
    test "labels abilities in STR DEX CON INT WIS CHR order" do
      character = Character.new([15, 14, 13, 12, 10, 8])
      assert Character.labeled(character) |> Enum.map(&elem(&1, 0)) == ~w(STR DEX CON INT WIS CHR)
    end
  end
end
