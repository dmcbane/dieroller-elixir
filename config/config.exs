import Config

# These are command line programs: they write their own output and never log.
# Silencing Logger keeps a closed downstream pipe -- `dieroller 1000x1d20 | head`
# -- from printing a crash report over the top of the results.
config :logger, level: :none
