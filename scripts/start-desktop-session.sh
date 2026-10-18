#!/usr/bin/env bash
set -euo pipefail

config="${DROIDSPACES_DESKTOP_CONFIG:-/etc/droidspaces-desktop.conf}"
[[ -r "$config" ]] || { echo "缺少桌面配置文件：$config" >&2; exit 1; }
source "$config"

if [[ "${DISPLAY_BACKEND:-}" == "anland-wayland" ]]; then
    # 确保 Anland socket 兼容路径与软链接存在
    for sock in /run/display.sock /data/local/tmp/display_daemon.sock /tmp/display_daemon.sock; do
        if [[ -S "$sock" ]]; then
            chmod 666 "$sock" 2>/dev/null || true
            mkdir -p /tmp/anland /data/local/tmp 2>/dev/null || true
            ln -sf "$sock" /tmp/display_daemon.sock 2>/dev/null || true
            ln -sf "$sock" /tmp/anland/display_daemon.sock 2>/dev/null || true
            ln -sf "$sock" /data/local/tmp/display_daemon.sock 2>/dev/null || true
            export ANLAND_SOCKET="$sock"
            break
        fi
    done

    # 避免合成器启动时被游戏覆盖层（如 MangoHud）注入导致崩溃
    unset MANGOHUD || true
fi

case "${DESKTOP:-}:${DISPLAY_BACKEND:-}" in
    none:x11) command_line='exit 0' ;;
    kde:x11) command_line='export DISPLAY="${DISPLAY:-:5}"; exec startplasma-x11' ;;
    kde:anland-wayland) command_line='exec startplasma-wayland' ;;
    kde-mobile:anland-wayland) command_line='exec startplasmamobile' ;;
    gnome:anland-wayland) command_line='exec gnome-session --session=gnome' ;;
    # Anland Next 的会话本体就是包内的 anland-session（会话 D-Bus + wayland
    # 链接 + rootless Xwayland + mini-wm），不经过任何桌面环境。用 /usr/bin 下
    # 的系统路径，不依赖用户家目录里的副本；XDG_RUNTIME_DIR 由脚本自己算，
    # systemd 用户管理器不可用时它只告警继续，所以不需要用户级单元先起来。
    anland-next:anland-wayland) command_line='exec /usr/bin/anland-session' ;;
    niri:anland-wayland) command_line='exec /usr/bin/niri-anland' ;;
    hyprland:anland-wayland) command_line='exec /usr/bin/hyprland-anland' ;;
    mango:anland-wayland) command_line='exec /usr/bin/mango-anland' ;;
    denial:anland-wayland) command_line='exec /usr/bin/denial-anland' ;;
    *)
        echo "不支持的桌面会话：${DESKTOP:-未设置}/${DISPLAY_BACKEND:-未设置}" >&2
        exit 1
        ;;
esac

if [[ "${DROIDSPACES_SESSION_DRY_RUN:-false}" == true ]]; then
    printf '%s\n' "$command_line"
    exit 0
fi

exec /bin/bash -lc "$command_line"
