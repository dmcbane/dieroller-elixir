defmodule DierollerCLI.Help do
  @moduledoc false

  @text """
  dieroller [ <option> ... ] [<arguments>] ...

    where the <arguments> are

      <notation>
    or
      <dice>
    or
      <dice> <sides>
    or
      <dice> <sides> <modifier>
    or
      <dice> <sides> <modifier> <keep>

    <notation> is standard dice notation: <dice>d<sides>[k<keep>][<modifier>],
    for example 3d6, 4d6k3, or 4d6k3+2.

    See the --dice, --sides, and --modifier parameters for details.

    Examples:

      dieroller 5
      dieroller 1 10
      dieroller 3 6 +3
      dieroller 3 6 +6 2
      dieroller 4d6k3
      dieroller 3d6+2 --json
      dieroller --dice 5 --sides 100 --modifier +4 --keep 3
      dieroller --dice 4 --sides 6 --keep 3

   where <option> is one of
    -v, --verbose : Display additional information (default to false).
    -d <dice>, --dice <dice> : Number of dice to roll.  Must be greater than 0.
      (default to 1)
    -k <keep>, --keep <keep> : Number of rolls to keep. Must be greater than 0 and less than or equal to <dice>.
      (default to number of dice)
    -m <modifier>, --modifier <modifier> : Modifier to the rolls. The first character can optionally
      be one of +, -, or * followed by a number.  If the +, -, or
      * are missing, + is assumed. (default to no modifier)
    -s <sides>, --sides <sides> : Number of sides per die. Must be greater than 0.
      (default to 20)
    -i <iterations>, --iterations <iterations> : Number of times to repeat the same rolls.  Must be greater than 0.
      (default to 1)
    -j, --json : Emit one JSON object per roll instead of text.
    --seed <seed> : Seed the random number generator for reproducible rolls.
    --help, -h : Show this help
  """

  @spec text() :: String.t()
  def text, do: @text
end
