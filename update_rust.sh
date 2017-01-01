#!/usr/bin/env bash

set -xueo pipefail

rustup update
rustup target add asmjs-unknown-emscripten
rustup target add wasm32-unknown-emscripten

for _pkg in racer rustfmt; do
    if which ${_pkg}; then
        cargo uninstall "${_pkg}"
    fi

    cargo install "${_pkg}"
done
