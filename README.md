# dieroller-elixir

[![CI](https://github.com/dmcbane/dieroller-elixir/actions/workflows/ci.yml/badge.svg)](https://github.com/dmcbane/dieroller-elixir/actions/workflows/ci.yml)

An Elixir port of [dieroller](https://github.com/dmcbane/dieroller): a command line die roller
and a Pathfinder character generator for tabletop RPG players.

Two commands are built from this repository:

- **`dieroller`** — roll N dice of S sides, keep the highest K, apply a modifier, repeat.
- **`pathfinder-character`** — generate Pathfinder ability scores by the classic, standard,
  heroic, pool, or purchase method.

## Layout

This is a Mix umbrella. All the logic lives in a pure core that performs no IO, so it can be
tested directly; the two CLI applications are thin shells over it.

```
apps/
  dice/            # pure core: dice specs, rolls, ability tables, purchase spreads
  dieroller_cli/   # -> dieroller
  pathfinder_cli/  # -> pathfinder-character
```

## dieroller

```
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

 where <option> is one of
  -v, --verbose : Display additional information (default to false).
  -d <dice>, --dice <dice> : Number of dice to roll.  Must be greater than 0. (default to 1)
  -k <keep>, --keep <keep> : Number of rolls to keep. Must be greater than 0 and less than
    or equal to <dice>. (default to number of dice)
  -m <modifier>, --modifier <modifier> : Modifier to the rolls. The first character can
    optionally be one of +, -, or * followed by a number. If the +, -, or * are missing,
    + is assumed. (default to no modifier)
  -s <sides>, --sides <sides> : Number of sides per die. Must be greater than 0. (default to 20)
  -i <iterations>, --iterations <iterations> : Number of times to repeat the same rolls.
    Must be greater than 0. (default to 1)
  -j, --json : Emit one JSON object per roll instead of text.
  --seed <seed> : Seed the random number generator for reproducible rolls.
  --help, -h : Show this help
```

### Dice notation

A single argument in standard dice notation replaces the positional form:

```
expression := term (('+' | '-') term)* ('*' integer)?
term       := dice | integer
dice       := integer 'd' integer selector?
selector   := 'k' ('h' | 'l')? integer     -- keep, defaulting to highest
            | 'd' ('h' | 'l')  integer     -- drop
```

| notation | meaning |
|---|---|
| `3d6` | roll three six-sided dice |
| `4d6k3`, `4d6kh3` | keep the highest three |
| `2d20kl1` | keep the lowest -- rolling with disadvantage |
| `2d20kh1` | keep the highest -- rolling with advantage |
| `4d6dl1` | drop the lowest (the same roll as `4d6k3`) |
| `4d6dh1` | drop the highest |
| `2d6+1d8-1` | several groups and constants |
| `3d6*2` | double the total of the kept dice |

Drop always needs its direction letter, since a bare `d` already separates dice
from sides. Dropping is stored as keeping from the other end, so `4d6dl1` and
`4d6k3` are the same spec and both display as `4D6K3`.

```console
$ dieroller 4d6k3 --iterations 6 --verbose
4D6K3 (5 4 4) => 13
4D6K3 (5 2 1) => 8
4D6K3 (5 3 1) => 9
4D6K3 (3 2 2) => 7
4D6K3 (6 5 4) => 15
4D6K3 (4 3 2) => 9
```

The modifier applies to the sum of the kept dice, not to each die, so `3d6*2` doubles the
total rather than rolling `3d12`.

### Examples

```console
$ dieroller 5                                        # 5d20
$ dieroller 1 10                                     # 1d10
$ dieroller 3 6 +3                                   # 3d6, +3 to the total
$ dieroller 3 6 +6 2                                 # 3d6, keep the best 2, +6
$ dieroller --dice 4 --sides 6 --keep 3              # same as 4d6k3
$ dieroller 2d20kl1                                  # disadvantage
$ dieroller 4d6dl1                                   # drop the lowest
$ dieroller 2d6+1d8-1 -v
2D6+1D8-1 (5 2) (6) => 12

$ dieroller 3d6+2 --json --seed 42
{"notation":"3D6+2","groups":[{"notation":"3D6","rolled":[4,1,3],"kept":[4,3,1],"sum":8}],"subtotal":10,"total":10}
```

Each dice group gets its own parentheses in verbose output and its own object
under `groups` in JSON, so a single-group expression reads exactly as it always
has.

## pathfinder-character

```
pathfinder-character [ <option> ... ]

 where <option> is one of
/ -c, --classic : The classic method: 3D6 per ability.
| -s, --standard : The standard method: 4D6 keep high 3 per ability. (this is the default)
| -r, --heroic : The heroic method: 2D6 plus 6 per ability.
| -l <diceperability>, --pool <diceperability> : The pool method: 24D6 for all 6 abilities.
|   The parameter specifies how many dice are assigned to each ability as follows:
|   3/3/3/3/3/9 with a minimum of 3 dice per ability.
| -p <purchasetype>, --purchase <purchasetype> : The purchase method: parameters are set
\   according to cost. low, standard, high, and epic provide 10, 15, 20, and 25 points.
  -v, --verbose : Display additional information (default to false).
  -n <n>, --number <n> : Number of characters to roll. Must be greater than 0. (default to 1)
  -j, --json : Emit one JSON object per character instead of text.
  --seed <seed> : Seed the random number generator for reproducible characters.
  --help, -h : Show this help
```

Characters are listed weakest first, so the best roll is the last line on screen.

```console
$ pathfinder-character --classic -v --number 4
STR: 11 DEX: 7 CON: 9 INT: 8 WIS: 7 CHR: 8 (bonus -7, cost -12)
STR: 13 DEX: 12 CON: 7 INT: 7 WIS: 16 CHR: 9 (bonus 0, cost 6)
STR: 14 DEX: 5 CON: 13 INT: 8 WIS: 13 CHR: 13 (bonus 1, cost 3)
STR: 13 DEX: 15 CON: 10 INT: 12 WIS: 8 CHR: 13 (bonus 4, cost 13)

$ pathfinder-character -s -n 3
12 12 5 10 12 15
12 17 13 15 12 8
16 6 17 14 11 12

$ pathfinder-character --pool 3:3:4:6:4:4 -v
STR: 11 DEX: 12 CON: 11 INT: 18 WIS: 10 CHR: 10 (bonus 5, cost 21)
```

## Building

Requires Erlang/OTP 28 and Elixir 1.19; `.tool-versions` pins the exact versions for
[asdf](https://asdf-vm.com).

### Standalone binaries

Self-contained executables that need no Erlang installed on the target machine, the
equivalent of Racket's `raco exe`. This needs [Zig](https://ziglang.org) 0.16.0, which
`.tool-versions` also pins:

```console
$ asdf install
$ MIX_ENV=prod mix release
$ ls burrito_out/
dieroller_linux  pathfinder_character_linux
```

Cross-compiling for Windows additionally needs `7z` (`apt install p7zip-full`); add the
`windows` target to `burrito_release/1` in `mix.exs` to enable it.

A Burrito binary unpacks itself once into `~/.local/share/.burrito/<name>_erts-<v>_<version>`
and reuses that install on later runs. During development the version rarely changes, so a
rebuilt binary will keep running the previously unpacked code. Bump the version in `mix.exs`
or delete that directory to pick up changes.

### Escripts

Faster to build and fine for local development, but they require Erlang on the machine that
runs them. An umbrella builds escripts per application, not from the root:

```console
$ (cd apps/dieroller_cli && mix escript.build)
$ ./apps/dieroller_cli/dieroller 4d6k3

$ (cd apps/pathfinder_cli && mix escript.build)
$ ./apps/pathfinder_cli/pathfinder-character -s -n 3
```

## Testing

```console
$ mix test
```

The suite covers the core with unit tests, doctests, and property-based tests
([StreamData](https://hex.pm/packages/stream_data)), and both CLIs end to end via `--seed`.

One test is tagged `:slow` and excluded by default. It reproduces the Racket original's
12⁶ = 2,985,984 nested-loop brute force and asserts it yields exactly the same set of
purchase spreads the Elixir version computes at compile time:

```console
$ mix test --include slow
```

## Ability score tables

```console
$ mix ability_scores --out ./csv [--legal-only]
```

Writes `legal_scores.csv` (12,376 spreads of scores 7..18) and `uniq_scores.csv`
(15,890,700 spreads of scores 1..45), each row carrying total purchase cost, total ability
bonus, and the six scores.

## Relationship to the Racket implementation

The [Racket implementation](https://github.com/dmcbane/dieroller-rkt) has been
brought in step with this one, so the two now accept the same arguments, produce
the same notation strings, and report the same validation messages. The
remaining differences are additions this port has and Racket does not:

| | Racket | Elixir |
|---|---|---|
| JSON output | not supported | `--json` on both commands |
| Reproducible rolls | not supported | `--seed <n>` on both commands |

Both implementations gained the following, and both were verified against the
other at each step:

- dice notation with keep/drop selectors and multiple dice groups
- options accepted after positional arguments
- validation errors on stderr with a non-zero exit status
- `pathfinder-character` printing one character per line rather than a raw
  list-of-lists dump, and no stray value line in verbose mode
- purchase characters with their abilities shuffled, rather than always sorted
  so that STR was the best stat
- `--keep 0` and an unrecognised `--purchase` type rejected rather than silently
  coerced
- the purchase spread table built from combinations with repetition (12,376
  spreads) rather than a 12^6 = 2,985,984 brute force
- `all_scores.csv`, which enumerated 45^6 orderings and never finished, dropped

## Verified against the Racket implementation

Checked directly against Racket 8.16:

- **Purchase spread table** -- dumped from the Racket implementation and diffed
  against this port's compile-time table. All 12,376 `(cost, bonus, spread)`
  triples are byte-identical, and the SHA-256 of that dump is pinned in
  `apps/dice/test/dice/pathfinder/purchase_test.exs`, so the agreement is
  enforced by the test suite without needing Racket installed.
- **Ability tables** -- cost and bonus for all 45 scores, identical.
- **Notation strings** -- identical for every argument form, legacy and new,
  including the `+0` suppression and drop-to-keep canonicalisation.
- **Validation messages** -- every message and both hint lines match byte for
  byte.
- **Roll distributions** -- 18,000 sampled 4D6-keep-3 scores track the exact
  theoretical distribution (chi-square 17.8 on 15 dof; critical value 30.6 at
  p = 0.01). `2d20kl1` and `2d20kh1` land on their theoretical means of 7.175
  and 13.825 in both implementations.
- **CSV output** -- `mix ability_scores --legal-only` and
  `racket all_ability_scores.rkt --legal-only` produce identical files.

## License

MIT. See [LICENSE](LICENSE).
