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

# 确保在用户主目录下执行
TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)"
TARGET_HOME="${TARGET_HOME:-$HOME}"

log "正在为用户 ${TARGET_USER} 配置 Steam 与游戏运行环境..." \
    "Configuring Steam and gaming runtime environment for user ${TARGET_USER}..."

# 1. 检查并配置 Wine / Hangover (Windows 游戏兼容层)
if ! command -v wine >/dev/null 2>&1; then
    log "检测到未安装 Wine，正在安装 Hangover Wine (支持 x86/x64 Windows 游戏)..." \
        "Wine not found, installing Hangover Wine (x86/x64 Windows games emulation)..."
    if [ -x /usr/local/sbin/install-hangover-wine ]; then
        /usr/local/sbin/install-hangover-wine --1 || warn "Hangover Wine 自动安装失败，可稍后在 dstui 中手动安装" \
            "Hangover Wine auto-install failed, you can install it manually in dstui later"
    fi
fi

# 2. 检查并配置 Wine 字体
if [ ! -d /usr/local/share/fonts/winefonts ] && [ -x /usr/local/sbin/install-winefonts ]; then
    log "正在安装游戏字体..." "Installing game fonts..."
    /usr/local/sbin/install-winefonts --1 || true
fi

# 3. 创建 Steam 相关目录结构
STEAM_ROOT="${TARGET_HOME}/.local/share/Steam"
STEAM_CONFIG="${TARGET_HOME}/.steam"
DESKTOP_DIR="${TARGET_HOME}/Desktop"
mkdir -p "$STEAM_ROOT" "$STEAM_CONFIG" "$DESKTOP_DIR"
mkdir -p "${TARGET_HOME}/.config/autostart"

# 4. 下载并提取官方 Steam 客户端引导文件 (Steam Bootstrap)
STEAM_TEMP="$(mktemp -d /tmp/steam-install.XXXXXX)"
cleanup() {
    rm -rf "$STEAM_TEMP"
}
trap cleanup EXIT

log "正在获取官方 Steam 引导程序..." "Downloading official Steam bootstrap..."
if curl -fsSL --retry 3 --connect-timeout 20 "https://cdn.cloudflare.steamstatic.com/client/installer/steam.deb" -o "$STEAM_TEMP/steam.deb"; then
    log "正在解压并部署 Steam 基础组件..." "Extracting and deploying Steam components..."
    (
        cd "$STEAM_TEMP"
        ar x steam.deb
        tar -xf data.tar.* -C "$STEAM_TEMP"
        
        # 复制图标
        if [ -d "$STEAM_TEMP/usr/share/icons" ]; then
            cp -rn "$STEAM_TEMP/usr/share/icons/"* /usr/share/icons/ 2>/dev/null || true
        fi
        
        # 复制 Steam 启动与库文件
        if [ -d "$STEAM_TEMP/usr/lib/steam" ]; then
            mkdir -p /usr/local/lib/steam
            cp -rn "$STEAM_TEMP/usr/lib/steam/"* /usr/local/lib/steam/ 2>/dev/null || true
            cp -rn "$STEAM_TEMP/usr/lib/steam/"* "$STEAM_ROOT/" 2>/dev/null || true
        fi
    )
    log "Steam 基础文件部署完成" "Steam base files deployed successfully"
else
    warn "下载 Steam 引导包失败，将使用内置启动脚本继续配置" \
         "Failed to download Steam deb package, proceeding with built-in launcher scripts"
fi

# 5. 配置手柄与游戏控制器权限 (Steam Controller / Xbox / PS4 / PS5 / Switch Pro)
log "正在配置游戏手柄权限与 udev 规则..." "Configuring game controller permissions and udev rules..."
mkdir -p /etc/udev/rules.d
cat > /etc/udev/rules.d/60-steam-input.rules <<'EOF_UDEV'
# Valve USB devices
SUBSYSTEM=="usb", ATTRS{idVendor}=="28de", MODE="0660", GROUP="input"
# Valve HID devices over USB gym
KERNEL=="hidraw*", ATTRS{idVendor}=="28de", MODE="0660", GROUP="input"
# Valve HID devices over Bluetooth HID
KERNEL=="hidraw*", KERNELS=="*28de:*", MODE="0660", GROUP="input"
# DualShock 4 over USB / Bluetooth
KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="05c4", MODE="0660", GROUP="input"
KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="09cc", MODE="0660", GROUP="input"
# DualSense (PS5) over USB / Bluetooth
KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0660", GROUP="input"
KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0df2", MODE="0660", GROUP="input"
# Nintendo Switch Pro Controller over USB / Bluetooth
KERNEL=="hidraw*", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="2009", MODE="0660", GROUP="input"
# Xbox 360 / Xbox One / Xbox Series controllers
KERNEL=="js*", MODE="0660", GROUP="input"
KERNEL=="event*", ATTRS{name}=="*Xbox*", MODE="0660", GROUP="input"
KERNEL=="event*", ATTRS{name}=="*Controller*", MODE="0660", GROUP="input"
KERNEL=="event*", ATTRS{name}=="*Gamepad*", MODE="0660", GROUP="input"
EOF_UDEV

# 6. 配置内核参数与文件句柄限制 (Proton / Steam 游戏必备)
mkdir -p /etc/sysctl.d /etc/security/limits.d
cat > /etc/sysctl.d/99-steam.conf <<'EOF_SYSCTL'
# Proton/Wine 需要庞大的虚拟内存区域映射，避免大型游戏启动崩溃
vm.max_map_count=2147483642
fs.file-max=524288
EOF_SYSCTL

cat > /etc/security/limits.d/99-steam.conf <<'EOF_LIMITS'
* soft nofile 1048576
* hard nofile 1048576
* soft memlock unlimited
* hard memlock unlimited
EOF_LIMITS

# 7. 创建桌面快捷方式
log "正在生成桌面快捷方式..." "Generating desktop shortcuts..."
cp -f /usr/share/applications/steam.desktop "$DESKTOP_DIR/" 2>/dev/null || true
cp -f /usr/share/applications/steam-gamepadui.desktop "$DESKTOP_DIR/" 2>/dev/null || true
chmod +x "$DESKTOP_DIR"/*.desktop 2>/dev/null || true

# 修正目录所有权
chown -R "${TARGET_USER}:${TARGET_USER}" "$TARGET_HOME/.local" "$STEAM_CONFIG" "$DESKTOP_DIR" 2>/dev/null || true

log "==================================================================" \
    "=================================================================="
log "Steam 与 SteamOS 游戏运行环境安装完成！" \
    "Steam and SteamOS gaming runtime installation complete!"
log "您可以在桌面或应用菜单中启动 Steam，或通过命令 'steam' 运行。" \
    "You can now launch Steam from Desktop/Application Menu, or run 'steam'."
log "如需进入类似 Steam Deck 的掌机全屏大屏幕模式，可运行 'steamos-session'。" \
    "To enter Steam Deck Gamepad UI Big Picture mode, run 'steamos-session'."
log "==================================================================" \
    "=================================================================="
