#!/usr/bin/env bash
SCRIPT_DIR=$(dirname "$0")
"$SCRIPT_DIR/build/debug/pony-lsd" --debug 2>> pony-lsd.log
