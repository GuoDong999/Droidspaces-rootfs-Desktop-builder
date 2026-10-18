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

# 防屏闪与同步优化变量
export ANLAND_SKIP_IMPLICIT_SYNC_WAIT=1
export ANLAND_PRESENT_BACKEND=legacy
export KWIN_WAYLAND_NO_IMPLICIT_SYNC=1
export KWIN_DRM_NO_DIRECT_SCANOUT=1
export MESA_VK_WSI_PRESENT_MODE=mailbox

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

# 3. 增强的 Steam 定位函数 (不区分大小写，兼顾多用户与多目录结构)
find_wine_steam() {
    local candidate
    local prefixes=()
    [ -n "${WINEPREFIX:-}" ] && prefixes+=("$WINEPREFIX")
    prefixes+=("${HOME}/.wine")

    # 如果当前用户下未找到，也搜索 /home 下其他普通用户目录
    for udir in /home/*; do
        [ -d "$udir/.wine" ] && prefixes+=("$udir/.wine")
    done

    for prefix in "${prefixes[@]}"; do
        [ -d "$prefix" ] || continue
        for sub in "drive_c/Program Files (x86)/Steam" \
                   "drive_c/Program Files/Steam" \
                   "drive_c/Steam"; do
            for bin in "Steam.exe" "steam.exe"; do
                candidate="$prefix/$sub/$bin"
                if [ -f "$candidate" ]; then
                    echo "$candidate"
                    return 0
                fi
            done
        done
        # 大小写不敏感深度查找
        if [ -d "$prefix/drive_c" ]; then
            candidate="$(find "$prefix/drive_c" -maxdepth 5 -iname "steam.exe" 2>/dev/null | head -n 1 || true)"
            if [ -n "$candidate" ] && [ -f "$candidate" ]; then
                echo "$candidate"
                return 0
            fi
        fi
    done
    return 1
}

STEAM_USER_DIR="${HOME}/.local/share/Steam"
STEAM_SYS_DIR="/usr/local/lib/steam"
WINE_STEAM="$(find_wine_steam || true)"

# 4. 检查是否正在运行或更新中
if pgrep -if "steam.exe" >/dev/null 2>&1; then
    echo "--> [SteamOS] 检测到 Steam 进程已在运行中..."
    if [ -n "$WINE_STEAM" ] && [ -f "$WINE_STEAM" ]; then
        exec wine "$WINE_STEAM" -gamepadui -steamos3 -fullscreen "$@"
    else
        # 正在安装向导或后台更新解压阶段
        if command -v zenity >/dev/null 2>&1 && [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then
            zenity --info --title="SteamOS" --text="Steam 正在后台更新或初始化中，请稍候..." --timeout=3 2>/dev/null || true
        fi
        exit 0
    fi
fi

# 5. 若未安装 Steam，自动触发初始化安装
if [ -z "$WINE_STEAM" ] && [ ! -x "${STEAM_USER_DIR}/steam.sh" ] && [ ! -x "${STEAM_SYS_DIR}/steam" ]; then
    echo "--> [SteamOS] 检测到尚未初始化 Steam 客户端，正在启动自动化环境部署..."

    if command -v zenity >/dev/null 2>&1 && [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then
        zenity --info --title="SteamOS" \
            --text="正在自动配置 Steam 掌机运行环境...\n首次运行将自动部署 Steam 客户端，请稍候。" \
            --timeout=4 2>/dev/null || true
    fi

    /usr/local/sbin/install-steam || true
    WINE_STEAM="$(find_wine_steam || true)"
fi

# 6. CEF 优化参数
cef_args=(
    -no-cef-sandbox
    -cef-disable-dev-shm-usage
    -cef-no-zygote
    --no-zygote
    --disable-gpu-sandbox
    -cef-ignore-gpu-blocklist
    -cef-enable-gpu-rasterization
)

# 7. 启动 Steam 客户端 (优先通过 Hangover Wine 启动 Steam Deck 大屏模式)
if [ -n "$WINE_STEAM" ] && [ -f "$WINE_STEAM" ] && command -v wine >/dev/null 2>&1; then
    echo "--> [SteamOS] 正在通过 Hangover Wine 启动 Steam Deck 掌机大屏模式..."
    export WINEPREFIX="${WINEPREFIX:-${HOME}/.wine}"
    exec wine "$WINE_STEAM" -gamepadui -steamos3 -fullscreen "${cef_args[@]}" "$@"
fi

# 8. 若有 Linux 本地客户端
if [ -x "${STEAM_USER_DIR}/steam.sh" ]; then
    exec "${STEAM_USER_DIR}/steam.sh" -gamepadui -steamos3 "${cef_args[@]}" "$@"
elif [ -x "${STEAM_SYS_DIR}/steam" ]; then
    exec "${STEAM_SYS_DIR}/steam" -gamepadui -steamos3 "${cef_args[@]}" "$@"
elif command -v steam >/dev/null 2>&1 && [ "$(command -v steam)" != "/usr/local/bin/steam" ]; then
    exec "$(command -v steam)" -gamepadui -steamos3 "${cef_args[@]}" "$@"
fi

echo "--> [SteamOS] 错误：无法启动 Steam，请在终端运行 'install-steam' 重新安装！" >&2
exit 1
