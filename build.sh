#!/bin/zsh
set -eu
ROOT="${0:A:h}"
export TARO_APP_OUTPUT="${TARO_APP_OUTPUT:-$ROOT/dist/Taro Octopus.app}"
exec /bin/zsh "$ROOT/work/octopus-pet/build.sh"
