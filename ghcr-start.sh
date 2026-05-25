#!/bin/bash
# Compatibility wrapper — use: ./start.sh --remote [args]
exec "$(dirname "$0")/start.sh" --remote "$@"
