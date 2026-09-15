#!/usr/bin/env bash

set -euo pipefail

runs="${MAX_PARALLEL_TEST_RUNS:-3}"
threads="${MAX_PARALLEL_TEST_THREADS:-16}"
scope="${MAX_PARALLEL_TEST_SCOPE:-all}"

case "$runs" in
    ''|*[!0-9]*|0)
        echo "MAX_PARALLEL_TEST_RUNS must be a positive integer (got: $runs)."
        exit 2
        ;;
esac

case "$threads" in
    ''|*[!0-9]*|0)
        echo "MAX_PARALLEL_TEST_THREADS must be a positive integer (got: $threads)."
        exit 2
        ;;
esac

case "$scope" in
    all)
        crates=(max-runtime max-channels)
        ;;
    channels)
        crates=(max-channels)
        ;;
    *)
        echo "MAX_PARALLEL_TEST_SCOPE must be 'channels' or 'all' (got: $scope)."
        exit 2
        ;;
esac

for crate in "${crates[@]}"; do
    for ((run = 1; run <= runs; run++)); do
        echo "==> parallel runtime regression: $crate run $run/$runs ($threads threads)"
        cargo test --locked --quiet -p "$crate" --lib -- --test-threads="$threads"
    done
done
