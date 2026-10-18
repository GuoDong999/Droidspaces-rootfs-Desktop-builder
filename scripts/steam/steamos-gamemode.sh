#!/usr/bin/env bash
# ==============================================================================
# SteamOS Game Mode Launcher
# ==============================================================================
set -euo pipefail

exec /usr/local/bin/steamos-session "$@"
