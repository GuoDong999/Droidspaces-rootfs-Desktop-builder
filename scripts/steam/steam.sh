#!/usr/bin/env bash
# ==============================================================================
# Steam Launcher for SteamOS / Droidspaces ARM64
# ==============================================================================
set -euo pipefail

# 1. 加载运行环境配置
if [ -r /run/droidspaces.env ]; then
    # shellcheck disable=SC1091
    . /run/droidspaces.env || true
fi
if [ -r /etc/environment ]; then
    # shellcheck disable=SC1091
    . /etc/environment || true
fi

# 2. 导出 SteamOS 与游戏优化环境变量
export STEAMOS=1
export STEAM_RUNTIME_PREFER_HOST_LIBRARIES=0
export PROTON_USE_WOW64=1
export PROTON_USE_NTSYNC=1
export PROTON_NO_NTSYNC=0
export DBUS_FATAL_WARNINGS=0
export NO_AT_BRIDGE=1
export GTK_USE_PORTAL=0
export GIO_USE_VFS=local
export WINEESYNC=1
export WINEFSYNC=1
export DXVK_ASYNC=1

# 音频与显示环境变量
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
mkdir -p "$XDG_RUNTIME_DIR" /dev/shm 2>/dev/null || true
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
chmod 1777 /dev/shm 2>/dev/null || true

export PULSE_SERVER="${PULSE_SERVER:-unix:/tmp/.pulse-socket}"
export PULSE_LATENCY_MSEC="${PULSE_LATENCY_MSEC:-20}"
export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-pulse}"

# 如果在 Wayland 环境下
if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -e "${XDG_RUNTIME_DIR}/wayland-0" ] || [ -e /run/display.sock ]; then
    export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
    export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-wayland}"
fi

# 3. 定位 Steam 运行文件
WINE_STEAM="${HOME}/.wine/drive_c/Program Files (x86)/Steam/Steam.exe"
STEAM_USER_DIR="${HOME}/.local/share/Steam"
STEAM_SYS_DIR="/usr/local/lib/steam"

# 若未找到 Steam.exe，搜索其他可能安装目录
if [ ! -f "$WINE_STEAM" ] && [ -d "${HOME}/.wine/drive_c" ]; then
    found_steam="$(find "${HOME}/.wine/drive_c" -name "Steam.exe" 2>/dev/null | head -n 1 || true)"
    if [ -n "$found_steam" ]; then
        WINE_STEAM="$found_steam"
    fi
fi

# 4. 若未安装 Steam，提示并引导自动安装
if [ ! -f "$WINE_STEAM" ] && [ ! -x "${STEAM_USER_DIR}/steam.sh" ] && [ ! -x "${STEAM_SYS_DIR}/steam" ]; then
    echo "--> [SteamOS] 检测到尚未安装 Steam 客户端，准备初始化安装..."

    # 优先使用图形向导提示
    if { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; } && command -v zenity >/dev/null 2>&1; then
        if zenity --question --title="SteamOS" \
            --text="检测到尚未安装 Steam 客户端。\n\n是否立即启动自动化安装程序配置 Steam 环境？" \
            --ok-label="立即安装" --cancel-label="取消" --width=360 2>/dev/null; then
            /usr/local/sbin/install-steam
            # 重新检测 Steam.exe 是否已生成
            if [ ! -f "$WINE_STEAM" ] && [ -d "${HOME}/.wine/drive_c" ]; then
                WINE_STEAM="$(find "${HOME}/.wine/drive_c" -name "Steam.exe" 2>/dev/null | head -n 1 || true)"
            fi
        else
            echo "--> 用户取消了 Steam 安装"
            exit 0
        fi
    else
        echo "=========================================================="
        echo " [SteamOS] 尚未安装完整的 Steam 客户端"
        echo " 正在为您启动一键安装程序..."
        echo "=========================================================="
        /usr/local/sbin/install-steam
        if [ ! -f "$WINE_STEAM" ] && [ -d "${HOME}/.wine/drive_c" ]; then
            WINE_STEAM="$(find "${HOME}/.wine/drive_c" -name "Steam.exe" 2>/dev/null | head -n 1 || true)"
        fi
    fi
fi

# 5. 容器内 Chromium 内核核心参数适配
cef_args=(
    -no-cef-sandbox
    -cef-disable-dev-shm-usage
    -cef-no-zygote
    --no-zygote
    --disable-gpu-sandbox
    -cef-ignore-gpu-blocklist
    -cef-enable-gpu-rasterization
)

# 6. 优先通过 Hangover Wine 启动 Windows Steam
if [ -f "$WINE_STEAM" ] && command -v wine >/dev/null 2>&1; then
    echo "--> [SteamOS] 正在通过 Hangover Wine 启动 Steam..."
    export WINEPREFIX="${HOME}/.wine"
    exec wine "$WINE_STEAM" "${cef_args[@]}" "$@"
fi

# 7. 若有 Linux 本地客户端
if [ -x "${STEAM_USER_DIR}/steam.sh" ]; then
    exec "${STEAM_USER_DIR}/steam.sh" "${cef_args[@]}" "$@"
elif [ -x "${STEAM_SYS_DIR}/steam" ]; then
    exec "${STEAM_SYS_DIR}/steam" "${cef_args[@]}" "$@"
elif command -v steam >/dev/null 2>&1 && [ "$(command -v steam)" != "/usr/local/bin/steam" ]; then
    exec "$(command -v steam)" "${cef_args[@]}" "$@"
fi

echo "--> [SteamOS] 错误：无法启动 Steam，请运行 'install-steam' 重新安装！" >&2
exit 1
