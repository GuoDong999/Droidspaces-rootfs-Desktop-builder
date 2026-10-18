#!/usr/bin/env bash
# ==============================================================================
# SteamOS Gaming Session Launcher (Gamescope + Steam Deck Gamepad UI)
# ==============================================================================
set -euo pipefail

# 载入环境
if [ -r /run/droidspaces.env ]; then
    . /run/droidspaces.env || true
fi
if [ -r /etc/environment ]; then
    . /etc/environment || true
fi

export STEAMOS=1
export STEAM_GAMEPADUI=1
export STEAM_MULTIPLE_XWAYLANDS=1
export STEAM_GAMESCOPE_VRR_SUPPORTED=1
export STEAM_USE_MANGOAPP=1
export ENABLE_GAMESCOPE_WSI=1

# 分辨率与刷新率自适应（默认 1280x800 60Hz，符合 Steam Deck 标准）
WIDTH="${STEAM_SCREEN_WIDTH:-1280}"
HEIGHT="${STEAM_SCREEN_HEIGHT:-800}"
REFRESH="${STEAM_SCREEN_REFRESH:-60}"

echo "--> [SteamOS] 正在启动 Steam Deck 掌机大屏幕模式 (Gamepad UI)..."

# 尝试启动 Gamescope，若容器环境无 KMS DRM 则平滑回退直接启动 Steam Gamepad UI
if command -v gamescope >/dev/null 2>&1; then
    echo "--> [SteamOS] 尝试启用 Gamescope 合成器 ($WIDTH x $HEIGHT @ ${REFRESH}Hz)..."
    gamescope -W "$WIDTH" -H "$HEIGHT" -r "$REFRESH" -e -- \
        /usr/local/bin/steam -gamepadui -steamos3 "$@" 2>/dev/null || {
            echo "--> [SteamOS] Gamescope 退出，回退到原生直接运行 Steam Gamepad UI"
            exec /usr/local/bin/steam -gamepadui -steamos3 "$@"
        }
else
    echo "--> [SteamOS] Gamescope 未就绪，直接启动 Steam Gamepad UI"
    exec /usr/local/bin/steam -gamepadui -steamos3 "$@"
fi
