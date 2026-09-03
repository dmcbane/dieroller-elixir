# The Racket-equivalence brute force is tagged :slow and skipped by default.
# Run it with: mix test --include slow
ExUnit.start(exclude: [:slow])
