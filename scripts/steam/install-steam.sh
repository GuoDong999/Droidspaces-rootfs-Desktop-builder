#!/usr/bin/env bash
# ==============================================================================
# Steam & SteamOS Gaming Environment Installer for Droidspaces
# ==============================================================================
set -euo pipefail

UI_LANG=zh
locale_name="${LC_ALL:-${LC_MESSAGES:-${LANG:-C}}}"
locale_name="${locale_name,,}"
[[ "$locale_name" != zh* ]] && UI_LANG=en

msg() {
    if [[ "$UI_LANG" == zh ]]; then
        printf '%s\n' "$1"
    else
        printf '%s\n' "$2"
    fi
}

log() {
    printf '\033[1;32m[SteamOS]\033[0m %s\n' "$(msg "$1" "$2")"
}

warn() {
    printf '\033[1;33m[SteamOS 警告]\033[0m %s\n' "$(msg "$1" "$2")" >&2
}

err() {
    printf '\033[1;31m[SteamOS 错误]\033[0m %s\n' "$(msg "$1" "$2")" >&2
    exit 1
}

# 目标用户与主目录（支持普通用户与 sudo 用户）
TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)"
TARGET_HOME="${TARGET_HOME:-$HOME}"
HAS_GUI=false
if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; then
    HAS_GUI=true
fi

show_gui_info() {
    local text="$1"
    if [ "$HAS_GUI" = true ] && command -v zenity >/dev/null 2>&1; then
        zenity --info --title="SteamOS" --text="$text" --width=350 2>/dev/null || true
    fi
}

show_gui_error() {
    local text="$1"
    if [ "$HAS_GUI" = true ] && command -v zenity >/dev/null 2>&1; then
        zenity --error --title="SteamOS" --text="$text" --width=350 2>/dev/null || true
    fi
}

log "正在为用户 ${TARGET_USER} 配置 Steam 与游戏运行环境..." \
    "Configuring Steam and gaming runtime environment for user ${TARGET_USER}..."

# 1. 确保目录结构存在
STEAM_DIR="${TARGET_HOME}/.wine/drive_c/Program Files (x86)/Steam"
DESKTOP_DIR="${TARGET_HOME}/Desktop"
mkdir -p "$DESKTOP_DIR" "${TARGET_HOME}/.config/autostart" "${TARGET_HOME}/.local/share/Steam"

# 2. 检查 Hangover Wine 运行环境
if ! command -v wine >/dev/null 2>&1; then
    log "检测到未安装 Wine，正在安装 Hangover Wine (支持 x86/x64 Windows 游戏与 Steam)..." \
        "Wine not found, installing Hangover Wine (x86/x64 Windows games & Steam emulation)..."
    if [ -x /usr/local/sbin/install-hangover-wine ]; then
        if [ "$(id -u)" -eq 0 ]; then
            /usr/local/sbin/install-hangover-wine --1 || warn "Hangover Wine 自动安装失败" "Hangover Wine auto-install failed"
        else
            sudo /usr/local/sbin/install-hangover-wine --1 || warn "Hangover Wine 自动安装失败" "Hangover Wine auto-install failed"
        fi
    fi
fi

if ! command -v wine >/dev/null 2>&1; then
    err "未检测到 Wine 环境，请先在终端运行 'sudo install-hangover-wine' 进行安装！" \
        "Wine environment not detected, please run 'sudo install-hangover-wine' first!"
    show_gui_error "未检测到 Wine 环境，请先在终端运行 'sudo install-hangover-wine' 进行安装！"
    exit 1
fi

# 3. 检查并安装游戏字体
if [ ! -d /usr/local/share/fonts/winefonts ] && [ -x /usr/local/sbin/install-winefonts ]; then
    log "正在配置游戏与 Wine 字体..." "Configuring game and Wine fonts..."
    if [ "$(id -u)" -eq 0 ]; then
        /usr/local/sbin/install-winefonts --1 || true
    else
        sudo /usr/local/sbin/install-winefonts --1 || true
    fi
fi

# 4. 获取或定位 Steam 官方 Windows 安装包
INSTALLER="/usr/local/share/steam/SteamSetup.exe"
TEMP_INSTALLER=""

if [ ! -f "$INSTALLER" ]; then
    INSTALLER="${TARGET_HOME}/.cache/SteamSetup.exe"
    mkdir -p "$(dirname "$INSTALLER")"
    if [ ! -f "$INSTALLER" ]; then
        log "正在下载 Steam 客户端安装包 (SteamSetup.exe)..." \
            "Downloading Steam client installer (SteamSetup.exe)..."
        if ! curl -fsSL --retry 3 --connect-timeout 15 "https://cdn.fastly.steamstatic.com/client/installer/SteamSetup.exe" -o "$INSTALLER"; then
            log "切换到官方备用源重试下载..." "Retrying from official fallback CDN..."
            curl -fsSL --retry 3 --connect-timeout 20 "https://media.steampowered.com/client/installer/SteamSetup.exe" -o "$INSTALLER" || true
        fi
    fi
fi

if [ ! -f "$INSTALLER" ] || [ ! -s "$INSTALLER" ]; then
    err "无法获取 Steam 安装程序 (SteamSetup.exe)，请检查网络连接！" \
        "Failed to download Steam installer (SteamSetup.exe), check your network connection!"
    show_gui_error "无法获取 Steam 安装程序 (SteamSetup.exe)，请检查网络连接！"
    exit 1
fi

# 5. 执行 Wine 静默安装 Steam
log "正在通过 Hangover Wine 部署 Steam 客户端..." \
    "Deploying Steam client via Hangover Wine..."

export WINEPREFIX="${TARGET_HOME}/.wine"
export WINEDEBUG=-all

# 初始化 wineprefix
if [ ! -d "${WINEPREFIX}/drive_c" ]; then
    log "初始化 Wine 环境..." "Initializing Wine prefix..."
    wineboot -u || true
fi

# 静默安装 Steam（/S 参数为 NSIS 标准静默安装）
log "正在静默安装 Steam..." "Silently installing Steam..."
wine "$INSTALLER" /S || true

# 等待安装完成
for i in {1..30}; do
    if [ -f "${STEAM_DIR}/Steam.exe" ]; then
        break
    fi
    sleep 1
done

if [ ! -f "${STEAM_DIR}/Steam.exe" ]; then
    # 若静默安装路径不同，尝试查找
    found_steam="$(find "${WINEPREFIX}/drive_c" -name "Steam.exe" 2>/dev/null | head -n 1 || true)"
    if [ -n "$found_steam" ]; then
        STEAM_DIR="$(dirname "$found_steam")"
    fi
fi

if [ -f "${STEAM_DIR}/Steam.exe" ]; then
    log "Steam.exe 已就绪: ${STEAM_DIR}/Steam.exe" "Steam.exe ready: ${STEAM_DIR}/Steam.exe"
else
    # 交互式启动一次安装向导兜底
    log "正在启动 Steam 图形安装向导..." "Launching Steam graphical setup wizard..."
    wine "$INSTALLER" || true
fi

# 6. 配置手柄权限与 udev（仅 root 执行时配置）
if [ "$(id -u)" -eq 0 ]; then
    mkdir -p /etc/udev/rules.d /etc/sysctl.d
    cat > /etc/udev/rules.d/60-steam-input.rules <<'EOF_UDEV'
SUBSYSTEM=="usb", ATTRS{idVendor}=="28de", MODE="0660", GROUP="input"
KERNEL=="hidraw*", ATTRS{idVendor}=="28de", MODE="0660", GROUP="input"
KERNEL=="hidraw*", KERNELS=="*28de:*", MODE="0660", GROUP="input"
KERNEL=="hidraw*", ATTRS{idVendor}=="054c", MODE="0660", GROUP="input"
KERNEL=="hidraw*", ATTRS{idVendor}=="057e", MODE="0660", GROUP="input"
KERNEL=="js*", MODE="0660", GROUP="input"
KERNEL=="event*", ATTRS{name}=="*Xbox*", MODE="0660", GROUP="input"
KERNEL=="event*", ATTRS{name}=="*Controller*", MODE="0660", GROUP="input"
KERNEL=="event*", ATTRS{name}=="*Gamepad*", MODE="0660", GROUP="input"
EOF_UDEV
    cat > /etc/sysctl.d/99-steam.conf <<'EOF_SYSCTL'
vm.max_map_count=2147483642
fs.file-max=524288
EOF_SYSCTL
fi

# 7. 刷新快捷方式
cp -f /usr/share/applications/steam.desktop "$DESKTOP_DIR/" 2>/dev/null || true
cp -f /usr/share/applications/steam-gamepadui.desktop "$DESKTOP_DIR/" 2>/dev/null || true
cp -f /usr/share/applications/steam-gamepadui.desktop "${TARGET_HOME}/.config/autostart/" 2>/dev/null || true
chmod +x "$DESKTOP_DIR"/*.desktop 2>/dev/null || true

# 修正目录所有权
if [ "$(id -u)" -eq 0 ] && [ "$TARGET_USER" != "root" ]; then
    chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.wine" "$DESKTOP_DIR" "${TARGET_HOME}/.config" "${TARGET_HOME}/.local" 2>/dev/null || true
fi

log "==================================================================" \
    "=================================================================="
log "Steam 与 SteamOS 游戏运行环境安装完成！" \
    "Steam and SteamOS gaming runtime installation complete!"
log "您可以在桌面直接启动 Steam 或 Steam Deck 大屏模式。" \
    "You can now launch Steam or Steam Deck Gamepad UI directly."
log "==================================================================" \
    "=================================================================="

show_gui_info "Steam 与 SteamOS 游戏运行环境安装完成！\n\n您现在可以在桌面上点击 Steam 或 Steam Deck 大屏模式启动。"
