#!/usr/bin/env sh

# Use greadlink on macOS.
if [ "$(uname)" = "Darwin" ]; then
  which greadlink > /dev/null || {
    printf 'GNU readlink not found\n'
    exit 1
  }
  alias readlink="greadlink"
fi

pwsh -NoProfile -NonInteractive -Command "& $(dirname "$(readlink -f -- "$0")")/build/build.ps1 $@"
