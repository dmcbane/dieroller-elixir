# dieroller-elixir

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
<dice>d<sides>[k<keep>][<modifier>]
```

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
$ dieroller 3d6+2 --json --seed 42
{"notation":"3D6+2","rolled":[4,1,3],"kept":[4,3,1],"subtotal":8,"total":10}
```

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

## Differences from the Racket original

Behavior is otherwise identical, including every validation message.

| | Racket | Elixir |
|---|---|---|
| Dice notation | not supported | `4d6k3+2` accepted as a single argument |
| JSON output | not supported | `--json` on both commands |
| Reproducible rolls | not supported | `--seed <n>` on both commands |
| Flags after positional arguments | `dieroller 5 -v` reads `-v` as the `<sides>` argument and crashes | accepted in any position |
| Validation errors | stdout, exit 0 | stderr, exit 1 |
| `pathfinder-character` plain output | one raw list-of-lists on a single line | one character per line |
| `pathfinder-character -v` | prints a stray `'((7 9 9 4 10 15) ...)` line after the report | no stray line |
| `--keep 0` | silently became `--keep <dice>` | rejected, as the help text always said |
| Unknown `--purchase` type | silently became `low` | rejected |
| Purchase spread table | memoized 12⁶ brute force at runtime | enumerated at compile time |
| `all_scores.csv` | 45⁶ ≈ 8.3 billion rows; never finishes | not generated (see `mix help ability_scores`) |

Racket's own option-parsing errors (an unknown flag, or two generation methods at once)
already exit 1; only its application-level validation messages exited 0.

## Verified against the original

Checked directly against Racket 8.16 running the original sources:

- **Purchase spread table** — dumped using the original's own `legal-purchase-uniq-sets`,
  `ability->cost`, and `ability->bonus-points`, then diffed against this port's compile-time
  table. All 12,376 `(cost, bonus, spread)` triples are byte-identical (same MD5).
- **Ability tables** — cost and bonus for all 45 scores, identical.
- **Dice notation strings** — identical for every argument form, including the `+0`
  suppression and unsigned-modifier cases.
- **Validation messages** — all nine messages plus both hint lines match byte for byte.
- **Roll distributions** — 18,000 sampled 4D6-keep-3 scores track the exact theoretical
  distribution (χ² = 17.8 on 15 dof; critical value 30.6 at p = 0.01), as does Racket's.
- **Pool weighting** — per-ability means for `9/3/3/3/3/3` agree within sampling noise
  (STR 15.78 vs 15.77; others 10.46 vs 10.44).

## License

MIT. See [LICENSE](LICENSE).
