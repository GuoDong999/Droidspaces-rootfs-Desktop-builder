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
unset ENABLE_GAMESCOPE_WSI || true
unset STEAM_USE_MANGOAPP || true
export ENABLE_GAMESCOPE_WSI=0

# 防屏闪与同步优化配置
export ANLAND_SKIP_IMPLICIT_SYNC_WAIT=1
export ANLAND_PRESENT_BACKEND=legacy
export KWIN_WAYLAND_NO_IMPLICIT_SYNC=1
export KWIN_DRM_NO_DIRECT_SCANOUT=1
export MESA_VK_WSI_PRESENT_MODE=mailbox

# 分辨率与刷新率自适应（默认 1280x800 60Hz，符合 Steam Deck 标准）
WIDTH="${STEAM_SCREEN_WIDTH:-1280}"
HEIGHT="${STEAM_SCREEN_HEIGHT:-800}"
REFRESH="${STEAM_SCREEN_REFRESH:-60}"

echo "--> [SteamOS] 正在启动 Steam Deck 掌机大屏幕模式 (Gamepad UI)..."

# 尝试启动 Gamescope（仅在存在标准 DRM KMS 设备时），若容器环境无 KMS DRM 则平滑回退直接全屏启动 Steam Gamepad UI
if command -v gamescope >/dev/null 2>&1 && [ -e /dev/dri/card0 ]; then
    echo "--> [SteamOS] 尝试启用 Gamescope 合成器 ($WIDTH x $HEIGHT @ ${REFRESH}Hz)..."
    gamescope -W "$WIDTH" -H "$HEIGHT" -r "$REFRESH" -e -- \
        /usr/local/bin/steam -gamepadui -steamos3 -fullscreen "$@" 2>/dev/null || {
            echo "--> [SteamOS] Gamescope 退出，回退到原生直接运行 Steam Gamepad UI"
            exec /usr/local/bin/steam -gamepadui -steamos3 -fullscreen "$@"
        }
else
    echo "--> [SteamOS] 直接启动 Steam Deck Gamepad UI (全屏模式)"
    exec /usr/local/bin/steam -gamepadui -steamos3 -fullscreen "$@"
fi
