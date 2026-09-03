defmodule Dice.Pathfinder.PurchaseTest do
  use ExUnit.Case, async: true
  doctest Dice.Pathfinder.Purchase

  alias Dice.Pathfinder.{Purchase, Tables}

  test "the compile-time table holds C(17, 6) spreads" do
    assert Purchase.set_count() == 12_376
  end

  test "every spread uses only legal scores, sorted descending" do
    for {_cost, spreads} <- Purchase.by_cost(), spread <- spreads do
      assert length(spread) == 6
      assert Enum.all?(spread, &(&1 in 7..18))
      assert spread == Enum.sort(spread, :desc)
    end
  end

  test "spreads are grouped under their true cost" do
    for {cost, spreads} <- Purchase.by_cost(), spread <- spreads do
      assert Tables.total_cost(spread) == cost
    end
  end

  describe "campaign types" do
    test "grant the published point totals" do
      assert Purchase.campaign_points(:low) == 10
      assert Purchase.campaign_points(:standard) == 15
      assert Purchase.campaign_points(:high) == 20
      assert Purchase.campaign_points(:epic) == 25
    end

    test "parse from any prefix, case insensitively" do
      assert Purchase.parse_campaign("low") == {:ok, :low}
      assert Purchase.parse_campaign("STANDARD") == {:ok, :standard}
      assert Purchase.parse_campaign("High Fantasy") == {:ok, :high}
      assert Purchase.parse_campaign("e") == {:ok, :epic}
    end

    test "reject an unrecognized type instead of silently choosing low" do
      assert {:error, message} = Purchase.parse_campaign("banana")
      assert message =~ "must be one of low, standard, high, or epic"
    end
  end

  describe "generate/1" do
    test "always spends exactly the available points" do
      for campaign <- [:low, :standard, :high, :epic] do
        points = Purchase.campaign_points(campaign)

        for _ <- 1..100 do
          assert {:ok, spread} = Purchase.generate(points)
          assert Tables.total_cost(spread) == points
        end
      end
    end

    test "reports an unreachable budget rather than crashing" do
      assert {:error, message} = Purchase.generate(9999)
      assert message =~ "no legal ability spread costs exactly 9999"
    end

    test "returns varied spreads" do
      spreads = for _ <- 1..200, do: elem(Purchase.generate(15), 1)
      assert length(Enum.uniq(spreads)) > 1
    end
  end

  # The canonical table, dumped from the Racket original itself (Racket 8.16,
  # using its own `legal-purchase-uniq-sets`, `ability->cost`, and
  # `ability->bonus-points`) and reduced to a digest. This pins the exact bytes
  # of the reference implementation's output without needing Racket installed or
  # the 12^6 brute force below to run.
  test "matches the digest of the table dumped from the Racket original" do
    canonical =
      for {cost, spreads} <- Purchase.by_cost(), spread <- spreads do
        "#{cost},#{Tables.total_bonus(spread)},#{Enum.join(spread, ",")}"
      end
      |> Enum.sort()
      |> Enum.map(&(&1 <> "\n"))

    digest = :crypto.hash(:sha256, canonical) |> Base.encode16(case: :lower)

    assert digest == "66d08d1a00f00e84eed3d202aa2e787c74bebd6b0f6e599e5d04a40b9211bcee"
  end

  # Reproduces the Racket original's 12^6 nested-loop brute force exactly and
  # asserts it yields the same set the compile-time enumeration does. This is
  # what makes the combinatorial rewrite safe; Racket is not installed here, so
  # it is the closest thing to a differential test against the original.
  @tag :slow
  @tag timeout: :infinity
  test "the compile-time table equals the Racket brute force" do
    legal = Enum.to_list(18..7//-1)

    brute_force =
      for str <- legal,
          dex <- legal,
          con <- legal,
          int <- legal,
          wis <- legal,
          chr <- legal,
          into: MapSet.new() do
        abilities = Enum.sort([str, dex, con, int, wis, chr], :desc)
        {Tables.total_cost(abilities), Tables.total_bonus(abilities), abilities}
      end

    ours =
      for {cost, spreads} <- Purchase.by_cost(), spread <- spreads, into: MapSet.new() do
        {cost, Tables.total_bonus(spread), spread}
      end

    assert MapSet.size(brute_force) == 12_376
    assert MapSet.equal?(brute_force, ours)
  end
end
