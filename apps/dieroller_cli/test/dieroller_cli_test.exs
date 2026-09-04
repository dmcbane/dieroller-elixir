defmodule DierollerCLITest do
  # Safe to run async: :rand seeding is per-process and ExUnit gives each test
  # its own process.
  use ExUnit.Case, async: true

  # Drains the lazy stream run/1 returns, so the tests exercise exactly the path
  # main/1 takes rather than a separate string-building one.
  defp run(argv) do
    case DierollerCLI.run(String.split(argv)) do
      {:ok, output} -> {:ok, output |> Enum.to_list() |> IO.iodata_to_binary()}
      error -> error
    end
  end

  defp lines(argv), do: run(argv) |> elem(1) |> String.split("\n", trim: true)

  describe "rolling" do
    test "a single die" do
      assert {:ok, out} = run("1d20 -v")
      assert out =~ ~r/^1D20 \(\d+\) => \d+\n$/
    end

    test "several dice" do
      assert {:ok, out} = run("5d20 -v")
      assert out =~ ~r/^5D20 \(\d+ \d+ \d+ \d+ \d+\) => \d+\n$/
    end

    test "a modifier" do
      assert run("3d1+3 -v") == {:ok, "3D1+3 (1 1 1) => 6\n"}
    end

    test "keeping the best of several" do
      assert {:ok, out} = run("4d6k3 -v")
      assert out =~ ~r/^4D6K3 \(\d+ \d+ \d+\) => \d+\n$/
    end

    test "advantage and disadvantage" do
      # kh is the default direction, so it renders as plain K.
      assert {:ok, high} = run("2d20kh1 -v")
      assert high =~ ~r/^2D20K1 \(\d+\) => \d+\n$/

      assert {:ok, low} = run("2d20kl1 -v")
      assert low =~ ~r/^2D20KL1 \(\d+\) => \d+\n$/
    end

    test "dropping dice" do
      assert {:ok, out} = run("4d6dl1 -v")
      assert out =~ ~r/^4D6K3 \(/
      assert {:ok, high} = run("4d6dh1 -v")
      assert high =~ ~r/^4D6KL3 \(/
    end

    test "several dice groups and constants" do
      assert run("2d1+1d1-1 -v") == {:ok, "2D1+1D1-1 (1 1) (1) => 2\n"}
      assert run("2d1-1d1 -v") == {:ok, "2D1-1D1 (1 1) (1) => 1\n"}
    end

    test "a trailing multiplier scales the whole expression" do
      assert run("2d1+3*2 -v") == {:ok, "2D1+3*2 (1 1) => 10\n"}
    end

    test "a quoted expression may contain spaces" do
      assert {:ok, out} = DierollerCLI.run(["2d6 + 1d8", "-v"])
      assert out |> Enum.join() =~ ~r/^2D6\+1D8 \(/
    end
  end

  describe "repeat count" do
    test "rolls the expression that many times" do
      assert lines("6x1d1") == ~w(1 1 1 1 1 1)
    end

    test "is not part of the rendered notation" do
      assert run("3x1d1 -v") == {:ok, "1D1 (1) => 1\n1D1 (1) => 1\n1D1 (1) => 1\n"}
    end

    test "defaults to one" do
      assert lines("1d1") == ["1"]
    end

    test "is case insensitive" do
      assert lines("2X1d1") == ~w(1 1)
    end

    test "must be greater than zero" do
      assert run("0x3d6") == {:error, "repeat count must be greater than 0."}
    end
  end

  describe "aggregates" do
    test "reduce the repeated rolls to one number" do
      assert lines("sum(6x1d1)") == ["6"]
      assert lines("avg(6x1d1)") == ["1"]
      assert lines("high(6x1d1)") == ["1"]
      assert lines("low(6x1d1)") == ["1"]
      assert lines("median(6x1d1)") == ["1"]
    end

    test "the colon form means the same as the parenthesised one" do
      assert run("sum:6x1d1") == run("sum(6x1d1)")
    end

    test "summarise exactly the rolls they replace" do
      rolls = "6x1d20 --seed 99" |> lines() |> Enum.map(&String.to_integer/1)

      assert lines("sum:6x1d20 --seed 99") == [to_string(Enum.sum(rolls))]
      assert lines("high:6x1d20 --seed 99") == [to_string(Enum.max(rolls))]
      assert lines("low:6x1d20 --seed 99") == [to_string(Enum.min(rolls))]
    end

    test "an average is rounded to two places" do
      # 7 + 1 + 15 over three rolls is 7.666..., which is as much precision as
      # three twenty-sided dice can honestly claim.
      assert lines("3x1d20 --seed 1") == ~w(7 1 15)
      assert lines("avg:3x1d20 --seed 1") == ["7.67"]
    end

    test "an average that lands on a whole number loses the decimal point" do
      assert lines("avg(2x1d1+1)") == ["2"]
    end

    test "an aggregate without a repeat count is the single roll" do
      assert lines("sum(3d1)") == ["3"]
    end

    test "verbose shows each roll and then the summary" do
      assert run("sum(3x1d1) -v") ==
               {:ok, "1D1 (1) => 1\n1D1 (1) => 1\n1D1 (1) => 1\nSUM(3x1D1) => 3\n"}
    end

    test "json emits one object for the whole batch" do
      assert {:ok, out} = run("sum(3x2d1) --json")

      assert JSON.decode!(out) == %{
               "notation" => "SUM(3x2D1)",
               "aggregate" => "sum",
               "expression" => "2D1",
               "repeat" => 3,
               "rolls" => [2, 2, 2],
               "value" => 6
             }
    end

    test "json reports the exact value, not the rounded one" do
      assert {:ok, out} = run("avg(3x1d1) --json")
      assert JSON.decode!(out)["value"] == 1.0
    end

    test "json wins over verbose, as it does for a plain roll" do
      assert run("sum(3x1d1) --json -v") == run("sum(3x1d1) --json")
    end

    test "every alias reaches its canonical notation" do
      assert {:ok, out} = run("max:2x1d1 -v")
      assert out =~ "HIGH(2x1D1) => 1"

      assert {:ok, out} = run("mean:2x1d1 -v")
      assert out =~ "AVG(2x1D1) => 1"
    end

    test "an aggregate is still lazy until it is drained" do
      assert {:ok, _output} = DierollerCLI.run(["sum:100000000x1d6"])
    end

    test "rejects an unknown aggregate" do
      assert run("worst(6x4d6k3)") ==
               {:error, ~s|unknown aggregate "worst"; use sum, avg, high, low, or median.|}
    end

    test "propagates the errors of the roll it wraps" do
      assert run("sum(0x1d6)") == {:error, "repeat count must be greater than 0."}
      assert run("sum(3x2d6k5)") == {:error, "dice must be greater than or equal to keep."}
      assert {:error, message} = run("sum(3x2)")
      assert message =~ "expression contains no dice"
    end
  end

  describe "output" do
    test "defaults to the total alone" do
      assert run("3d1") == {:ok, "3\n"}
    end

    test "verbose shows notation, kept dice, and total" do
      assert run("3d1+2 -v") == {:ok, "3D1+2 (1 1 1) => 5\n"}
    end

    test "json emits one object per roll" do
      assert {:ok, out} = run("2d1 --json")

      assert JSON.decode!(out) == %{
               "notation" => "2D1",
               "groups" => [
                 %{"notation" => "2D1", "rolled" => [1, 1], "kept" => [1, 1], "sum" => 2}
               ],
               "subtotal" => 2,
               "total" => 2
             }
    end

    test "json reports each group separately" do
      assert {:ok, out} = run("2d1+1d1 --json")
      decoded = JSON.decode!(out)
      assert length(decoded["groups"]) == 2
      assert decoded["total"] == 3
    end

    test "json with a repeat count emits one object per line" do
      objects = "3x2d1 --json" |> lines() |> Enum.map(&JSON.decode!/1)
      assert length(objects) == 3
    end
  end

  describe "informational flags" do
    test "help describes the notation" do
      assert {:ok, help} = run("--help")
      assert help =~ "dieroller [ <option> ... ] <roll>"
      assert help =~ "kl<n>"
      assert help =~ "6x4d6k3"
    end

    test "help is available as -h" do
      assert run("-h") == run("--help")
    end

    test "version reports the application version" do
      assert {:ok, out} = run("--version")
      assert out =~ ~r/^dieroller \d+\.\d+\.\d+\n$/
    end

    test "version is available as -V" do
      assert run("-V") == run("--version")
    end

    test "help wins over a roll" do
      assert {:ok, out} = run("4d6k3 --help")
      assert out =~ "dieroller [ <option> ... ]"
    end
  end

  describe "seeding" do
    test "the same seed gives byte-identical output" do
      assert run("10x10d100 --seed 42 -v") == run("10x10d100 --seed 42 -v")
    end

    test "different seeds diverge" do
      refute run("20d1000 --seed 1") == run("20d1000 --seed 2")
    end
  end

  describe "streaming" do
    test "output is lazy, so a huge repeat count costs nothing until drained" do
      assert {:ok, output} = DierollerCLI.run(["100000000x1d6"])
      assert output |> Enum.take(3) |> length() == 3
    end
  end

  describe "errors" do
    test "requires an expression" do
      assert run("-v") == {:error, "no dice expression given."}
    end

    test "rejects an expression with no dice" do
      assert {:error, message} = run("2+3")
      assert message =~ "expression contains no dice"
    end

    test "propagates notation errors" do
      assert run("2d6k5") == {:error, "dice must be greater than or equal to keep."}
      assert run("2d0") == {:error, "sides must be greater than 0."}
      assert run("0d6") == {:error, "dice must be greater than 0."}
      assert run("4d6dl4") == {:error, "keep must be greater than 0."}
      assert {:error, message} = run("4d6d1")
      assert message =~ "could not parse dice notation"
    end

    test "rejects unknown options" do
      assert run("--bogus") == {:error, "unrecognized option --bogus."}
    end

    # The flags and positional arguments the notation replaced.
    test "the removed dice flags are no longer accepted" do
      for flag <- ~w(--dice --sides --keep --modifier --iterations) do
        assert {:error, message} = run("#{flag} 3")
        assert message =~ "unrecognized option #{flag}"
      end
    end

    test "the old positional form suggests its notation equivalent" do
      assert {:error, message} = run("5")
      assert message =~ "try: dieroller 5d20"

      assert {:error, message} = run("3 6")
      assert message =~ "try: dieroller 3d6"

      assert {:error, message} = run("3 6 +3")
      assert message =~ "try: dieroller 3d6+3"

      assert {:error, message} = run("3 6 +6 2")
      assert message =~ "try: dieroller 3d6k2+6"
    end

    test "an unquoted spaced expression suggests quoting" do
      assert {:error, message} = run("2d6 + 1d8")
      assert message =~ "quote the whole expression"
      assert message =~ ~s(dieroller "2d6 + 1d8")
    end

    test "trailing junk after a valid expression suggests quoting" do
      assert {:error, message} = run("4d6k3 extra")
      assert message =~ "one argument"
    end
  end
end
