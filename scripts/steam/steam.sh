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
export STEAM_RUNTIME=1
export STEAM_RUNTIME_PREFER_HOST_LIBRARIES=0
export PROTON_USE_WOW64=1
export PROTON_USE_NTSYNC=1
export PROTON_NO_NTSYNC=0
export DBUS_FATAL_WARNINGS=0
export NO_AT_BRIDGE=1
export GTK_USE_PORTAL=0
export GIO_USE_VFS=local
export MANGOHUD="${MANGOHUD:-1}"

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

# 3. 检查 Steam 运行根目录
STEAM_USER_DIR="${HOME}/.local/share/Steam"
STEAM_SYS_DIR="/usr/local/lib/steam"

# 若初次运行未初始化，执行安装配置
if [ ! -d "$STEAM_USER_DIR" ] && [ ! -d "$STEAM_SYS_DIR" ]; then
    echo "--> [SteamOS] 首次运行 Steam，正在进行环境初始化..."
    if [ -x /usr/local/sbin/install-steam ]; then
        /usr/local/sbin/install-steam || true
    fi
fi

# 4. 容器内 CEF (Chromium Embedded Framework) 核心参数适配
# 解决 Android 容器内无沙箱权限导致的 Chromium 崩溃
cef_args=(
    -no-cef-sandbox
    -cef-disable-dev-shm-usage
    -cef-no-zygote
    --no-zygote
    --disable-gpu-sandbox
    -cef-ignore-gpu-blocklist
    -cef-enable-gpu-rasterization
)

# 5. 定位并启动 Steam
# 优先启动原生/跨架构 Steam Linux 客户端
if [ -x "${STEAM_USER_DIR}/steam.sh" ]; then
    exec "${STEAM_USER_DIR}/steam.sh" "${cef_args[@]}" "$@"
elif [ -x "${STEAM_SYS_DIR}/steam" ]; then
    exec "${STEAM_SYS_DIR}/steam" "${cef_args[@]}" "$@"
elif command -v steam >/dev/null 2>&1 && [ "$(command -v steam)" != "/usr/local/bin/steam" ]; then
    exec "$(command -v steam)" "${cef_args[@]}" "$@"
fi

# 6. 如果未找到原生 Linux Steam 可执行文件，检测 Hangover Wine Windows Steam
WINE_STEAM="${HOME}/.wine/drive_c/Program Files (x86)/Steam/Steam.exe"
if [ -f "$WINE_STEAM" ] && command -v wine >/dev/null 2>&1; then
    echo "--> [SteamOS] 正在通过 Hangover Wine 启动 Steam..."
    exec wine "$WINE_STEAM" -no-cef-sandbox "$@"
fi

# 7. 引导用户完成一键安装
echo "=========================================================="
echo " [SteamOS] 尚未安装完整的 Steam 客户端"
echo " 请运行 'sudo install-steam' 完成一键安装与依赖部署。"
echo "=========================================================="
if [ -t 0 ]; then
    read -r -p "是否现在立即运行安装程序？[Y/n] " answer
    case "${answer:-y}" in
        [yY]*)
            sudo /usr/local/sbin/install-steam
            exec "$0" "$@"
            ;;
    esac
fi
exit 1
