defmodule DierollerCLITest do
  # Safe to run async: :rand seeding is per-process and ExUnit gives each test
  # its own process.
  use ExUnit.Case, async: true

  defp run(argv), do: DierollerCLI.run(String.split(argv))

  describe "argument forms" do
    test "a bare count rolls that many d20s" do
      assert {:ok, out} = run("5 -v")
      assert out =~ ~r/^5D20 \(\d+ \d+ \d+ \d+ \d+\) => \d+\n$/
    end

    test "two positionals are dice and sides" do
      assert {:ok, out} = run("1 10 -v")
      assert out =~ ~r/^1D10 \(\d+\) => \d+\n$/
    end

    test "three positionals add a modifier" do
      assert {:ok, out} = run("3 6 +3 -v")
      assert out =~ ~r/^3D6\+3 \(/
    end

    test "four positionals add a keep count" do
      assert {:ok, out} = run("3 6 +6 2 -v")
      assert out =~ ~r/^3D6K2\+6 \(\d+ \d+\) => \d+\n$/
    end

    test "long flags work" do
      assert {:ok, out} = run("--dice 5 --sides 100 --modifier +4 --keep 3 -v")
      assert out =~ ~r/^5D100K3\+4 \(/
    end

    test "dice notation is accepted" do
      assert {:ok, out} = run("4d6k3 -v")
      assert out =~ ~r/^4D6K3 \(\d+ \d+ \d+\) => \d+\n$/
    end

    test "positionals and flags merge slot by slot, as the original did" do
      assert {:ok, out} = run("3 --sides 6 -v")
      assert out =~ ~r/^3D6 \(/
    end

    test "an omitted --keep still defaults to the dice count" do
      assert {:ok, out} = run("--dice 4 --sides 6 -v")
      assert out =~ ~r/^4D6 \(/
    end

    test "a modifier without a sign is treated as addition" do
      assert {:ok, out} = run("3 6 3 -v")
      assert out =~ ~r/^3D6\+3 \(/
    end
  end

  describe "output" do
    test "defaults to the total alone" do
      assert {:ok, out} = run("3 1")
      assert out == "3\n"
    end

    test "verbose shows notation, kept dice, and total" do
      assert run("3 1 +2 -v") == {:ok, "3D1+2 (1 1 1) => 5\n"}
    end

    test "iterations emit one line each" do
      assert {:ok, out} = run("2 1 --iterations 3")
      assert out == "2\n2\n2\n"
    end

    test "json emits one object per line" do
      assert {:ok, out} = run("2 1 --json --iterations 2")
      [a, b] = String.split(out, "\n", trim: true)
      assert JSON.decode!(a) == JSON.decode!(b)

      assert JSON.decode!(a) == %{
               "notation" => "2D1",
               "rolled" => [1, 1],
               "kept" => [1, 1],
               "subtotal" => 2,
               "total" => 2
             }
    end

    test "help is returned as output, not an error" do
      assert {:ok, help} = run("--help")
      assert help =~ "dieroller [ <option> ... ]"
      assert help =~ "--iterations"
    end
  end

  describe "seeding" do
    test "the same seed gives byte-identical output" do
      assert run("10 100 --seed 42 -i 5 -v") == run("10 100 --seed 42 -i 5 -v")
    end

    test "different seeds diverge" do
      refute run("20 1000 --seed 1 -v") == run("20 1000 --seed 2 -v")
    end
  end

  describe "errors" do
    test "reports the original validation messages" do
      assert run("0") == {:error, "dice must be greater than 0."}
      assert run("3 6 +6 7") == {:error, "dice must be greater than or equal to keep."}
      assert run("3 0") == {:error, "sides must be greater than 0."}
      assert run("--dice 3 --keep 0 --sides 6") == {:error, "keep must be greater than 0."}
      assert run("3 6 +0 0") == {:error, "keep must be greater than 0."}
      assert run("-i 0") == {:error, "iterations must be greater than 0."}
    end

    test "rejects unknown options" do
      assert run("--bogus") == {:error, "unrecognized option --bogus."}
    end

    test "rejects trailing junk after notation" do
      assert {:error, message} = run("4d6k3 extra")
      assert message =~ "unexpected arguments after dice notation"
    end

    test "rejects non-numeric positionals" do
      assert {:error, message} = run("abc")
      assert message =~ "dice must be a number"
    end
  end
end
