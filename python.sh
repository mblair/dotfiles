#!/usr/bin/env bash

set -xueo pipefail

if [[ $(uname -s) == "Darwin" ]]; then
    for _pkg in python black; do
        brew install ${_pkg} || brew upgrade ${_pkg}
    done
fi
