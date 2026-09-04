defmodule DierollerCLI.Help do
  @moduledoc false

  @text """
  dieroller [ <option> ... ] <roll>

    A roll is written entirely in dice notation, as a single argument:

      <roll>       := [<repeat>x] <expression>
      <expression> := <term> (('+' | '-') <term>)* ['*' <integer>]
      <term>       := <dice> | <integer>
      <dice>       := <count>d<sides>[<selector>]

      <selector> is one of
        k<n>, kh<n>  keep the highest <n> dice (k defaults to highest)
        kl<n>        keep the lowest <n> dice   (roll with disadvantage)
        dl<n>        drop the lowest <n> dice
        dh<n>        drop the highest <n> dice

    A modifier applies to the sum of the kept dice, not to each die, so 3d6*2
    doubles the total rather than rolling 3d12. Quote the expression if you
    write it with spaces.

    Examples:

      dieroller 1d20                 a single twenty-sided die
      dieroller 5d20                 five of them
      dieroller 3d6+3                three six-sided dice, plus three
      dieroller 4d6k3                keep the best three of four
      dieroller 2d20kh1              advantage
      dieroller 2d20kl1              disadvantage
      dieroller 4d6dl1              drop the lowest of four
      dieroller 2d6+1d8-1            several dice groups and a constant
      dieroller 3d6*2                double the total
      dieroller 6x4d6k3              roll the same thing six times
      dieroller 6x4d6k3 --verbose    show the dice that were kept
      dieroller "2d6 + 1d8"          spaces are fine when quoted

   where <option> is one of
    -v, --verbose : Show the notation and the dice that were kept.
    -j, --json : Emit one JSON object per roll instead of text.
    --seed <seed> : Seed the random number generator for reproducible rolls.
    -V, --version : Show the version
    -h, --help : Show this help
  """

  @spec text() :: String.t()
  def text, do: @text
end
