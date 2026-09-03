defmodule PathfinderCLITest do
  use ExUnit.Case, async: true

  defp run(argv), do: PathfinderCLI.run(String.split(argv))
  defp lines(argv), do: run(argv) |> elem(1) |> String.split("\n", trim: true)

  describe "generation methods" do
    test "defaults to the standard method" do
      assert run("-n 1") |> elem(0) == :ok
      assert lines("-n 5") |> length() == 5
    end

    test "classic rolls 3D6, so scores span 3..18" do
      assert_scores_within("--classic -n 40", 3..18)
    end

    test "standard rolls 4D6 keep 3, so scores span 3..18" do
      assert_scores_within("--standard -n 40", 3..18)
    end

    test "heroic rolls 2D6 plus 6, so scores never fall below 8" do
      assert_scores_within("--heroic -n 40", 8..18)
    end

    test "pool accepts a distribution and produces six abilities" do
      for line <- lines("--pool 3:3:4:6:4:4 -n 5") do
        assert line |> String.split() |> length() == 6
      end
    end

    test "purchase spends exactly the campaign budget" do
      for {flag, points} <- [{"low", 10}, {"standard", 15}, {"high", 20}, {"epic", 25}] do
        for line <- lines("-p #{flag} -n 10 -v") do
          assert line =~ "cost #{points})", "#{flag} produced: #{line}"
        end
      end
    end

    test "short flags match the original" do
      assert run("-c -n 1") |> elem(0) == :ok
      assert run("-s -n 1") |> elem(0) == :ok
      assert run("-r -n 1") |> elem(0) == :ok
      assert run("-l 3/3/3/3/3/9 -n 1") |> elem(0) == :ok
      assert run("-p high -n 1") |> elem(0) == :ok
    end

    defp assert_scores_within(argv, range) do
      scores =
        argv
        |> lines()
        |> Enum.flat_map(&String.split/1)
        |> Enum.map(&String.to_integer/1)

      assert Enum.all?(scores, &(&1 in range)),
             "expected all scores in #{inspect(range)}, got #{inspect(Enum.min_max(scores))}"
    end
  end

  describe "output" do
    test "plain output is one character per line, six scores each" do
      for line <- lines("-n 4") do
        assert line =~ ~r/^\d+( \d+){5}$/
      end
    end

    test "verbose labels each ability and reports both totals" do
      [line] = lines("-n 1 -v")

      assert line =~
               ~r/^STR: \d+ DEX: \d+ CON: \d+ INT: \d+ WIS: \d+ CHR: \d+ \(bonus -?\d+, cost -?\d+\)$/
    end

    test "characters are listed weakest first" do
      bonuses =
        "-n 15 -v"
        |> lines()
        |> Enum.map(fn line ->
          [_, bonus] = Regex.run(~r/\(bonus (-?\d+),/, line)
          String.to_integer(bonus)
        end)

      assert bonuses == Enum.sort(bonuses)
    end

    test "json emits one object per character" do
      objects = "-p standard -n 3 --json" |> lines() |> Enum.map(&JSON.decode!/1)
      assert length(objects) == 3

      for object <- objects do
        assert object["method"] == "purchase 15"
        assert object["cost_total"] == 15
        assert length(object["scores"]) == 6
        assert Map.keys(object["abilities"]) |> Enum.sort() == ~w(CHR CON DEX INT STR WIS)
      end
    end

    test "json records the pool distribution" do
      [object] = "--pool 3/3/3/3/3/9 -n 1 --json" |> lines() |> Enum.map(&JSON.decode!/1)
      assert object["method"] == "pool 3/3/3/3/3/9"
    end

    test "help is output, not an error" do
      assert {:ok, help} = run("--help")
      assert help =~ "pathfinder-character"
      assert help =~ "--purchase"
    end
  end

  describe "seeding" do
    test "the same seed gives byte-identical output" do
      assert run("-s -n 5 --seed 5 -v") == run("-s -n 5 --seed 5 -v")
    end

    test "different seeds diverge" do
      refute run("-s -n 5 --seed 1") == run("-s -n 5 --seed 2")
    end
  end

  describe "errors" do
    test "reports the original pool validation messages" do
      assert run("--pool 3/3/3/3/3") ==
               {:error, "dice per attribute must specify die quantity for six attributes."}

      assert run("--pool 2/3/3/3/3/10") ==
               {:error, "a minimum of 3 dice must be used for each attribute."}

      assert run("--pool 3/3/3/3/3/3") ==
               {:error, "you must specify a total of twenty-four dice for the pool."}
    end

    test "reports the original character-count message" do
      assert run("-n 0") == {:error, "number of characters must be greater than 0."}
    end

    test "rejects an unknown purchase type instead of defaulting to low" do
      assert {:error, message} = run("-p banana")
      assert message =~ "must be one of low, standard, high, or epic"
    end

    test "rejects two generation methods" do
      assert {:error, message} = run("--classic --heroic")
      assert message =~ "choose only one generation method"
    end

    test "rejects unknown options and stray arguments" do
      assert run("--bogus") == {:error, "unrecognized option --bogus."}
      assert run("extra") == {:error, ~s(unexpected argument "extra".)}
    end
  end
end
