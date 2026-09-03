defmodule PathfinderCLI.Help do
  @moduledoc false

  @text """
  pathfinder-character [ <option> ... ]

    Examples:

      pathfinder-character --classic -v --number 10
      pathfinder-character -s -n 3
      pathfinder-character --pool 3:3:4:6:4:4 -v
      pathfinder-character -p epic -n 5 --json

   where <option> is one of
  / -c, --classic : The classic method: 3D6 per ability.
  | -s, --standard : The standard method: 4D6 keep high 3 per ability.
  |   (this is the default)
  | -r, --heroic : The heroic method: 2D6 plus 6 per ability.
  | -l <diceperability>, --pool <diceperability> : The pool method: 24D6 for all 6 abilities. The parameter
  |   specifies how many dice are assigned to each ability as
  |   follows: 3/3/3/3/3/9 with a minimum of 3 dice per ability.
  | -p <purchasetype>, --purchase <purchasetype> : The purchase method: parameters are set according to cost.
  |   The parameter specifies the purchase type as follows: low,
  |   standard, high, and epic fantasy which provides 10, 15, 20,
  \\   and 25 purchase points respectively.
    -v, --verbose : Display additional information (default to false).
    -n <n>, --number <n> : Number of characters to roll. Must be greater than 0.
      (default to 1)
    -j, --json : Emit one JSON object per character instead of text.
    --seed <seed> : Seed the random number generator for reproducible characters.
    --help, -h : Show this help
  """

  @spec text() :: String.t()
  def text, do: @text
end
