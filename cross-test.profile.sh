# Sourced by cross-test; keep this file to settings assignments only.
# Use Zig 0.17's published matrix and standard test step; do not set a subset.
# Limit parallelism to four jobs for memory use during C++ builds.

CROSS_BUILD_STEP=test
CROSS_BUILD_JOBS=4
CROSS_BUILD_TIMEOUT=7200
CROSS_TIMEOUT=1800