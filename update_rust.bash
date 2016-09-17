#!/usr/bin/env bash

set -xueo pipefail

multirust update nightly
multirust default nightly

for _pkg in racer rustfmt; do
    cargo uninstall "${_pkg}"
    cargo install "${_pkg}"
done
