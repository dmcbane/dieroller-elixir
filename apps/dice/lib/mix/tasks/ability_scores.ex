defmodule Mix.Tasks.AbilityScores do
  @shortdoc "Writes ability score cost/bonus tables to CSV"

  @moduledoc """
  Generates ability score analysis tables as CSV.

      mix ability_scores [--out DIR] [--legal-only]

  Two files are produced:

    * `legal_scores.csv` -- the 12,376 spreads buyable with purchase points
      (scores 7..18)
    * `uniq_scores.csv`  -- all 15,890,700 spreads across the full extrapolated
      table (scores 1..45)

  The Racket original also wrote `all_scores.csv`, enumerating every *ordering*
  of six scores: 45^6 is roughly 8.3 billion rows, which does not finish in any
  practical time. Every one of those rows is a permutation of a spread already
  present in `uniq_scores.csv`, and neither cost nor bonus depends on ability
  order, so that file carries no information the unique table lacks. It is
  deliberately not generated.

  ## Options

    * `--out DIR` -- directory to write into (default: the current directory)
    * `--legal-only` -- write only `legal_scores.csv`
  """

  use Mix.Task

  alias Dice.Combinations
  alias Dice.Pathfinder.Tables

  @abilities 6
  @chunk 10_000
  @header "cost,bonus,s1,s2,s3,s4,s5,s6\n"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args, strict: [out: :string, legal_only: :boolean], aliases: [o: :out])

    dir = Keyword.get(opts, :out, ".")
    File.mkdir_p!(dir)

    write(dir, "legal_scores.csv", Tables.legal_scores())

    if opts[:legal_only] do
      Mix.shell().info("Skipped uniq_scores.csv (--legal-only).")
    else
      write(dir, "uniq_scores.csv", Tables.scores())
    end

    Mix.shell().info("""
    Skipped all_scores.csv: 45^6 is about 8.3 billion rows, one per ordering of
    six scores. Cost and bonus do not depend on ability order, so every such row
    duplicates a spread already in uniq_scores.csv.\
    """)
  end

  defp write(dir, filename, score_range) do
    path = Path.join(dir, filename)
    pool = score_range |> Enum.reverse() |> Enum.to_list()
    expected = Combinations.count(Enum.count(score_range), @abilities)

    Mix.shell().info("Writing #{path} (#{format_count(expected)} rows)...")

    {microseconds, written} = :timer.tc(fn -> stream_to_file(path, pool) end)

    ^expected = written
    Mix.shell().info("  done in #{Float.round(microseconds / 1_000_000, 1)}s")
  end

  # Rows are built lazily and flushed in chunks, so memory stays flat no matter
  # how large the table is.
  defp stream_to_file(path, pool) do
    file = File.open!(path, [:write, :raw, :binary])

    try do
      IO.binwrite(file, @header)

      pool
      |> Combinations.stream(@abilities)
      |> Stream.map(&row/1)
      |> Stream.chunk_every(@chunk)
      |> Enum.reduce(0, fn chunk, count ->
        IO.binwrite(file, chunk)
        count + length(chunk)
      end)
    after
      File.close(file)
    end
  end

  defp row(scores) do
    [
      Integer.to_string(Tables.total_cost(scores)),
      ?,,
      Integer.to_string(Tables.total_bonus(scores)),
      ?,,
      Enum.map_intersperse(scores, ?,, &Integer.to_string/1),
      ?\n
    ]
  end

  defp format_count(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end
end
