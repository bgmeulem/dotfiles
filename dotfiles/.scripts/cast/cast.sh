#!/usr/bin/env bash
# Simple wrapper script that can be aliased on unix

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

uv --project="$SCRIPT_DIR" run python "$SCRIPT_DIR"/main.py "$@";
