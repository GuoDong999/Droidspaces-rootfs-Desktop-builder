FROM debian:trixie AS customizer

#######################################################
ARG DESKTOP=kde
ARG DESKTOP_AUTOSTART=true
ARG PulseAudio=socket
ARG ENABLE_zh_tz_ARG=true
ARG ENABLE_binfmt_ARG=true
ARG ENABLE_yj_ARG=true
ARG ENABLE_mesa_ARG=true
ARG ENABLE_kfgj_ARG=false
ARG ENABLE_zip_ARG=true
ARG ENABLE_docker_ARG=false
ARG ENABLE_srf_ARG=true
ARG DISPLAY_BACKEND=x11
ARG ENABLE_8gen2_wayland_ARG=false
ARG ENABLE_systemd257_ARG=false
ARG USERNAME=deck
ARG ANLAND_RELEASE_REPOSITORY=Goldzxcbug/droidspaces-package
ARG ANLAND_PACKAGE_REVISION=unknown
######################################################

ENV DEBIAN_FRONTEND=noninteractive

# 启用 APT 并行连接、HTTP(S) pipeline 和下载重试
RUN printf '%s\n' \
    'Acquire::Queue-Mode "host";' \
    'Acquire::http::Pipeline-Depth "10";' \
    'Acquire::https::Pipeline-Depth "10";' \
    'Acquire::Retries "3";' \
    > /etc/apt/apt.conf.d/99parallel-downloads

# 更新基础系统并启用 non-free（非自由）和 contrib 软件源
RUN (sed -i 's/main/main contrib non-free non-free-firmware/g' /etc/apt/sources.list 2>/dev/null || sed -i 's/Components: main/Components: main contrib non-free non-free-firmware/g' /etc/apt/sources.list.d/debian.sources 2>/dev/null || true) && \
    apt-get update && \
    apt-get upgrade -y

# 复制自定义与管理脚本
COPY scripts/download-firmware /usr/local/bin/
COPY scripts/bashrc.sh /etc/profile.d/ds-aliases.sh
COPY scripts/install-usb-manager.sh /usr/local/sbin/install-droidspaces-usb-manager
COPY scripts/systemd257.sh /usr/local/sbin/systemd257
COPY scripts/tui/install-anland-kde.sh /usr/local/sbin/install-anland-kde
COPY scripts/tui/install-anland-gnome.sh /usr/local/sbin/install-anland-gnome
COPY scripts/tui/install-anland-next.sh /usr/local/sbin/install-anland-next
COPY scripts/tui/install-anland-niri.sh /usr/local/sbin/install-anland-niri
COPY scripts/tui/install-anland-hyprland.sh /usr/local/sbin/install-anland-hyprland
COPY scripts/tui/install-anland-mango.sh /usr/local/sbin/install-anland-mango
COPY scripts/tui/install-anland-denial.sh /usr/local/sbin/install-anland-denial
COPY scripts/install-anland-desktop.sh /usr/local/sbin/install-anland-desktop
COPY scripts/tui/install-mesa.sh /usr/local/sbin/install-mesa
COPY scripts/tui/install-winefonts.sh /usr/local/sbin/install-winefonts
COPY scripts/tui/droidspaces-tui.sh /usr/local/bin/droidspaces-tui
COPY scripts/install-desktop.sh /usr/local/sbin/install-desktop
COPY scripts/configure-desktop.sh /usr/local/sbin/configure-desktop
COPY scripts/configure-chrome.sh /usr/local/sbin/configure-chrome
COPY scripts/start-desktop-session.sh /usr/local/bin/start-desktop-session
COPY scripts/desktops/ /usr/local/lib/droidspaces/desktops/

# 赋予相关脚本可执行权限
RUN chmod +x /usr/local/bin/download-firmware /etc/profile.d/ds-aliases.sh /usr/local/sbin/install-anland-* /usr/local/sbin/install-mesa /usr/local/sbin/install-winefonts /usr/local/sbin/install-desktop /usr/local/sbin/configure-desktop /usr/local/sbin/configure-chrome /usr/local/bin/droidspaces-tui /usr/local/bin/start-desktop-session /usr/local/lib/droidspaces/desktops/*.sh && \
    ln -s droidspaces-tui /usr/local/bin/dstui && \
    ln -s droidspaces-tui /usr/local/bin/ds-tui

RUN sed -i 's|^path-exclude=/usr/share/locale/\*/LC_MESSAGES/\*.mo|#&|' \
        /etc/dpkg/dpkg.cfg.d/excludes 2>/dev/null || true

# 安装核心工具、图形栈、手柄与多架构环境支持
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    bash jq dialog coreutils file findutils grep sed gawk curl wget ca-certificates locales bash-completion udev dbus systemd-sysv systemd-resolved fastfetch \
    git nano sudo openssh-server net-tools iptables iputils-ping iproute2 dnsutils procps kmod tzdata tar gpg \
    mesa-utils vulkan-tools pulseaudio-utils zenity cabextract libevdev2 evtest pciutils usbutils xdg-utils xdg-user-dirs strace binutils \
    qemu-user-static binfmt-support && \
    /usr/local/sbin/install-desktop "$DESKTOP" && \
    # 输入法 fcitx5 (可选)
    if [ "$ENABLE_srf_ARG" = "true" ]; then \
        apt-get install -y fcitx5; \
    fi && \
    if [ "$ENABLE_srf_ARG" = "true" ] && [ "$ENABLE_zh_tz_ARG" = "true" ]; then \
        apt-get install -y fcitx5-chinese-addons; \
    fi && \
    ## 开发工具集成 (可选)
    if [ "$ENABLE_kfgj_ARG" = "true" ]; then \
        apt-get install -y --no-install-recommends \
        build-essential gcc g++ make cmake autoconf automake libtool pkg-config clang llvm python3 python3-pip python3-dev python3-venv python-is-python3; \
    fi && \
    ## 压缩工具扩展 (可选)
    if [ "$ENABLE_zip_ARG" = "true" ]; then \
        apt-get install -y --no-install-recommends \
        zip unzip p7zip-full bzip2 xz-utils tar gzip; \
    fi && \
    ## docker (可选)
    if [ "$ENABLE_docker_ARG" = "true" ]; then \
        apt-get install -y --no-install-recommends \
        docker.io docker-compose docker-cli; \
    fi && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 设置 SteamOS 发行版身份标识
RUN cat > /etc/os-release <<'EOF'
NAME="SteamOS"
PRETTY_NAME="SteamOS 3 (Linux Native X11 Edition)"
ID=debian
ID_LIKE="steamos"
VERSION_ID="13"
VERSION="13 (trixie)"
VERSION_CODENAME=trixie
BUILD_ID="rolling"
ANSI_COLOR="1;35"
HOME_URL="https://store.steampowered.com/steamos"
DOCUMENTATION_URL="https://github.com/GuoDong999/Droidspaces-rootfs-Desktop-builder"
SUPPORT_URL="https://github.com/GuoDong999/Droidspaces-rootfs-Desktop-builder/issues"
BUG_REPORT_URL="https://github.com/GuoDong999/Droidspaces-rootfs-Desktop-builder/issues"
LOGO=steamos
VARIANT="Steam Deck & Handheld Gaming (Linux Native + Proton + X11)"
VARIANT_ID=steamdeck-native-x11
STEAMOS=1
EOF
RUN cp -f /etc/os-release /usr/lib/os-release 2>/dev/null || true && \
    echo "3.6.0-native-x11" > /etc/steamos-version

# 强制配置使用 iptables-legacy
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy && \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# 配置 Locale 与 SSH
RUN sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen && \
    if [ "$ENABLE_zh_tz_ARG" = "true" ]; then \
        export DEBIAN_FRONTEND=noninteractive && \
        ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
        echo "Asia/Shanghai" > /etc/timezone && \
        dpkg-reconfigure -f noninteractive tzdata && \
        sed -i '/zh_CN.UTF-8/s/^# //' /etc/locale.gen && \
        locale-gen && \
        update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8; \
    else \
        locale-gen && \
        update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8; \
    fi && \
    mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    (deluser --remove-home debian 2>/dev/null || true) && \
    useradd -m -s /bin/bash ${USERNAME} && echo "${USERNAME}:1234" | chpasswd

# 为所有 Debian RootFS 安装 Droidspaces USB Manager
RUN /usr/local/sbin/install-droidspaces-usb-manager --user "${USERNAME}"

# 安装 Box64 (用于 ARM64 下直接运行 Linux 原生 x86_64 软件与 Proton 游戏兼容层)
RUN wget -qO- https://ryanfortner.github.io/box64-debs/KEY.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/box64-debs-archive-keyring.gpg && \
    echo "deb https://ryanfortner.github.io/box64-debs/debian ./" > /etc/apt/sources.list.d/box64.list && \
    apt-get update && \
    (apt-get install -y --no-install-recommends box64 || true) && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 安装官方 Linux 原生 Steam 客户端与依赖环境
RUN mkdir -p /tmp/steam-install && cd /tmp/steam-install && \
    (curl -fsSL --retry 3 --connect-timeout 20 "https://cdn.cloudflare.steamstatic.com/client/installer/steam.deb" -o steam.deb || \
     curl -fsSL --retry 3 --connect-timeout 20 "https://repo.steampowered.com/steam/archive/stable/steam_latest.deb" -o steam.deb) && \
    ar x steam.deb && \
    tar xf data.tar.xz -C / && \
    cd / && rm -rf /tmp/steam-install

# 预安装游戏通用字体
RUN echo "--> [SteamOS] 预安装游戏字体..." && \
    /usr/local/sbin/install-winefonts --1 || echo "--> [跳过] 离线构建环境中跳过字体下载"

# 部署 GE-Proton / Proton 安装辅助脚本
RUN cat > /usr/local/sbin/install-ge-proton <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
USER_NAME="${1:-deck}"
COMPAT_DIR="/home/${USER_NAME}/.local/share/Steam/compatibilitytools.d"
mkdir -p "$COMPAT_DIR"

echo "--> 正在检查 GE-Proton 兼容层最新版本..."
LATEST_TAG=$(curl -fsSL https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') || LATEST_TAG="GE-Proton11-9"
TAR_NAME="${LATEST_TAG}-aarch64.tar.gz"
DOWNLOAD_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${LATEST_TAG}/${TAR_NAME}"

echo "--> 正在下载 ${TAR_NAME}..."
if curl -fsSL --retry 3 --connect-timeout 30 "$DOWNLOAD_URL" -o "/tmp/${TAR_NAME}"; then
    echo "--> 正在解压至 ${COMPAT_DIR}..."
    tar -xzf "/tmp/${TAR_NAME}" -C "$COMPAT_DIR"
    rm -f "/tmp/${TAR_NAME}"
    chown -R "${USER_NAME}:${USER_NAME}" "$COMPAT_DIR"
    echo "--> GE-Proton 安装完成！"
else
    echo "--> [提示] 无法自动下载 aarch64 GE-Proton，可在进入桌面后手动解压至 ${COMPAT_DIR}"
fi
EOF
RUN chmod +x /usr/local/sbin/install-ge-proton

# 创建掌机专属 Linux 原生 Steam 封装器与开机直启脚本
RUN cat > /usr/local/bin/steam <<'EOF'
#!/usr/bin/env bash
set -e

# 音频与显示环境变量
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
mkdir -p "$XDG_RUNTIME_DIR" /dev/shm 2>/dev/null || true
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
chmod 1777 /dev/shm 2>/dev/null || true

export DISPLAY="${DISPLAY:-:5}"
export SDL_VIDEODRIVER="x11"
export GDK_BACKEND="x11"
export QT_QPA_PLATFORM="xcb"

export PULSE_SERVER="${PULSE_SERVER:-unix:/tmp/.pulse-socket}"
export PULSE_LATENCY_MSEC="${PULSE_LATENCY_MSEC:-20}"
export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-pulse}"

# Steam 掌机与 Proton 兼容层环境变量
export STEAMOS=1
export STEAM_RUNTIME=1
export PROTON_USE_WOW64=1
export PROTON_USE_NTSYNC=1
export DBUS_FATAL_WARNINGS=0

# Box64 转译引擎优化环境变量
export BOX64_BINFMT=1
export BOX64_NOBANNER=1
export BOX64_DYNAREC=1
export BOX64_DYNAREC_WAIT=1
export BOX64_DYNAREC_FASTNAN=1
export BOX64_DYNAREC_FASTROUND=1
export BOX64_DYNAREC_X87DOUBLE=0
export BOX64_STEAM_VULKAN=1
export BOX64_EMULATED_LIBS="libstdc++.so.6:libGL.so.1"

# 检查原生 Steam 核心客户端
REAL_STEAM="/usr/bin/steam"
if [ ! -x "$REAL_STEAM" ] && [ -x /usr/lib/steam/bin_steam.sh ]; then
    REAL_STEAM="/usr/lib/steam/bin_steam.sh"
fi

# 参数透传：默认开启 Steam Deck 掌机全屏大屏模式
if [ $# -eq 0 ]; then
    set -- -gamepadui -fullscreen -steamos3
fi

echo "--> [SteamOS] 正在启动 Linux 原生 Steam 掌机模式 (X11)..."
exec "$REAL_STEAM" "$@"
EOF
RUN chmod +x /usr/local/bin/steam && \
    ln -sf /usr/local/bin/steam /usr/local/bin/steamos-session

# 预置 Steam Deck 掌机默认配置（强制全局启用 Proton SteamPlay）
RUN mkdir -p /home/${USERNAME}/.local/share/Steam/config /home/${USERNAME}/.local/share/Steam/compatibilitytools.d && \
    cat > /home/${USERNAME}/.local/share/Steam/config/config.vdf <<'EOF'
"InstallConfigStore"
{
	"Software"
	{
		"Valve"
		{
			"Steam"
			{
				"SteamPlay"		"1"
				"CompatToolMapping"
				{
					"0"
					{
						"name"		"proton_experimental"
						"config"		""
						"priority"		"250"
					}
				}
			}
		}
	}
}
EOF
RUN chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.local 2>/dev/null || true

# 部署游戏手柄 udev 规则与 Steam/Proton 虚拟内存优化参数
RUN mkdir -p /etc/udev/rules.d /etc/sysctl.d && \
    cat > /etc/udev/rules.d/60-steam-input.rules <<'EOF'
SUBSYSTEM=="usb", ATTRS{idVendor}=="28de", MODE="0660", GROUP="input"
KERNEL=="hidraw*", ATTRS{idVendor}=="28de", MODE="0660", GROUP="input"
KERNEL=="hidraw*", KERNELS=="*28de:*", MODE="0660", GROUP="input"
KERNEL=="hidraw*", ATTRS{idVendor}=="054c", MODE="0660", GROUP="input"
KERNEL=="hidraw*", ATTRS{idVendor}=="057e", MODE="0660", GROUP="input"
KERNEL=="js*", MODE="0660", GROUP="input"
KERNEL=="event*", ATTRS{name}=="*Xbox*", MODE="0660", GROUP="input"
KERNEL=="event*", ATTRS{name}=="*Controller*", MODE="0660", GROUP="input"
KERNEL=="event*", ATTRS{name}=="*Gamepad*", MODE="0660", GROUP="input"
EOF
RUN cat > /etc/sysctl.d/99-steam.conf <<'EOF'
vm.max_map_count=2147483642
fs.file-max=524288
EOF

# 创建 Steam Deck Gamepad UI 桌面快捷方式与开机自启动
RUN mkdir -p /usr/share/applications /etc/xdg/autostart /home/${USERNAME}/Desktop /home/${USERNAME}/.config/autostart /etc/skel/Desktop /etc/skel/.config/autostart && \
    cat > /usr/share/applications/steam-gamepadui.desktop <<'EOF'
[Desktop Entry]
Name=Steam Gamepad UI (Deck Mode)
Comment=Launch Linux Native Steam in Steam Deck Gamepad UI
Exec=/usr/local/bin/steam -gamepadui -fullscreen -steamos3
Icon=steam
Terminal=false
Type=Application
Categories=Game;Network;FileTransfer;
StartupNotify=true
EOF
RUN cp -f /usr/share/applications/steam-gamepadui.desktop /etc/xdg/autostart/ && \
    cp -f /usr/share/applications/steam-gamepadui.desktop /home/${USERNAME}/Desktop/ && \
    cp -f /usr/share/applications/steam-gamepadui.desktop /home/${USERNAME}/.config/autostart/ && \
    cp -f /usr/share/applications/steam*.desktop /home/${USERNAME}/Desktop/ 2>/dev/null || true && \
    chmod +x /home/${USERNAME}/Desktop/*.desktop 2>/dev/null || true && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/Desktop /home/${USERNAME}/.config 2>/dev/null || true

# 初始化环境变量文件
RUN : > /etc/environment
RUN cat >> /etc/environment <<'EOF'
DISPLAY=:5
STEAMOS=1
STEAM_RUNTIME=1
PROTON_USE_WOW64=1
PROTON_USE_NTSYNC=1
BOX64_BINFMT=1
BOX64_NOBANNER=1
EOF

# 音频配置
RUN if [ "$PulseAudio" = "socket" ]; then \
        echo "PULSE_SERVER=unix:/tmp/.pulse-socket" >> /etc/environment; \
    elif [ "$PulseAudio" = "tcp" ]; then \
        echo "PULSE_SERVER=tcp:127.0.0.1:4713" >> /etc/environment; \
    fi

# 输入法与桌面会话配置
COPY scripts/start/ /tmp/droidspaces-start/
RUN <<'EOF_RUN'
    if [ "$ENABLE_srf_ARG" = "true" ]; then
    mkdir -p /home/${USERNAME}/.config/autostart
    cat <<'EOF' > /home/${USERNAME}/.config/autostart/fcitx5.desktop
[Desktop Entry]
Name=Fcitx5
GenericName=Input Method
Comment=Start Input Method
Exec=fcitx5 -d
Icon=fcitx
Terminal=false
Type=Application
Categories=System;Utility;
StartupNotify=false
NoDisplay=true
EOF
    cat <<'EOF' >> /etc/environment
XMODIFIERS=@im=fcitx5
GTK_IM_MODULE=fcitx5
QT_IM_MODULE=fcitx5
SDL_IM_MODULE=fcitx5
GLFW_IM_MODULE=fcitx
EOF
    fi

    echo 'export XDG_RUNTIME_DIR=/run/user/$(id -u)' >> /home/${USERNAME}/.bashrc
    /usr/local/sbin/configure-desktop "$DESKTOP" "$DISPLAY_BACKEND" "$DESKTOP_AUTOSTART" "$USERNAME"
    rm -rf /tmp/droidspaces-start
EOF_RUN

# Mesa 驱动安装
RUN if [ "$ENABLE_mesa_ARG" = "true" ]; then \
        /usr/local/sbin/install-mesa --1; \
    else \
        echo "--> [跳过] 未开启 Mesa 驱动安装"; \
    fi

# 安装并配置 Google Chrome
RUN /usr/local/sbin/configure-chrome "$DESKTOP" "$DISPLAY_BACKEND"

# DHCP 网络配置
RUN mkdir -p /etc/systemd/network && \
    cat <<'EOF' > /etc/systemd/network/10-eth-dhcp.network
[Match]
Name=eth*

[Network]
DHCP=yes
IPv6AcceptRA=yes

[DHCPv4]
UseDNS=yes
UseDomains=yes
RouteMetric=100
EOF

# Android 运行环境兼容性修复
RUN <<'EOF_RUN'
grep -q '^aid_inet:' /etc/group     || echo 'aid_inet:x:3003:'    >> /etc/group
grep -q '^aid_net_raw:' /etc/group || echo 'aid_net_raw:x:3004:' >> /etc/group
grep -q '^aid_net_admin:' /etc/group || echo 'aid_net_admin:x:3005:' >> /etc/group

getent group droidspaces-gpu >/dev/null || groupadd -g 786 -r droidspaces-gpu
usermod -a -G aid_inet,aid_net_raw,input,video,tty,droidspaces-gpu root || true
usermod -a -G aid_inet,aid_net_raw,input,video,tty,sudo,droidspaces-gpu ${USERNAME} || true

grep -q '^_apt:' /etc/passwd && usermod -g aid_inet _apt || true

if [ -f /etc/adduser.conf ]; then
    sed -i '/^EXTRA_GROUPS=/d; /^ADD_EXTRA_GROUPS=/d' /etc/adduser.conf
    echo 'ADD_EXTRA_GROUPS=1' >> /etc/adduser.conf
    echo 'EXTRA_GROUPS="aid_inet aid_net_raw input video tty"' >> /etc/adduser.conf
fi

ln -sf /dev/null /etc/systemd/system/systemd-networkd-wait-online.service
ln -sf /dev/null /etc/systemd/system/systemd-journald-audit.socket

cat >> /etc/systemd/journald.conf << 'EOT'
[Journal]
ReadKMsg=no
Audit=no
Storage=volatile
EOT

mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/ds-logging.conf << 'EOT'
[Journal]
SystemMaxUse=200M
RuntimeMaxUse=200M
MaxRetentionSec=7day
MaxLevelStore=info
EOT

mkdir -p /etc/systemd/system/multi-user.target.wants
GUEST_SYSTEMD_PATH="/lib/systemd/system"

if [ -f "$GUEST_SYSTEMD_PATH/dbus.service" ]; then
    ln -sf "$GUEST_SYSTEMD_PATH/dbus.service" "/etc/systemd/system/multi-user.target.wants/dbus.service"
fi

if [ "$ENABLE_yj_ARG" = "true" ]; then
    for service in systemd-udevd.service systemd-resolved.service systemd-networkd.service NetworkManager.service; do
        if [ -f "$GUEST_SYSTEMD_PATH/$service" ]; then
            ln -sf "$GUEST_SYSTEMD_PATH/$service" "/etc/systemd/system/multi-user.target.wants/$service"
        fi
    done
else
    for service in systemd-udevd.service systemd-resolved.service systemd-networkd.service NetworkManager.service; do
        ln -sf /dev/null "/etc/systemd/system/$service"
    done
fi

mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/99-power-key.conf << 'EOF'
[Login]
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandlePowerKeyLongPress=ignore
HandlePowerKeyLongPressHibernate=ignore
EOF

mkdir -p /etc/systemd/system/systemd-udev-trigger.service.d
cat > /etc/systemd/system/systemd-udev-trigger.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/udevadm trigger --subsystem-match=usb --subsystem-match=block --subsystem-match=input --subsystem-match=tty --subsystem-match=net
EOF

for unit in systemd-udevd.service systemd-udev-trigger.service systemd-udev-settle.service systemd-udevd-kernel.socket systemd-udevd-control.socket; do
    mkdir -p "/etc/systemd/system/${unit}.d"
    printf "[Unit]\nConditionPathIsReadWrite=\n" > "/etc/systemd/system/${unit}.d/99-readonly-fix.conf"
done

for unit in NetworkManager.service dhcpcd.service systemd-resolved.service systemd-networkd.service; do
    if [ -f "$GUEST_SYSTEMD_PATH/$unit" ] || [ -f "/etc/systemd/system/multi-user.target.wants/$unit" ]; then
        mkdir -p "/etc/systemd/system/${unit}.d"
        cat > "/etc/systemd/system/${unit}.d/99-netmode-limit.conf" << 'EOF'
[Service]
ExecCondition=
ExecCondition=/bin/sh -c "grep -qE 'net_mode=(nat|gateway)' /run/droidspaces/container.config"
EOF
    fi
done

for unit in systemd-udevd.service systemd-udev-trigger.service systemd-udev-settle.service; do
    if [ -f "$GUEST_SYSTEMD_PATH/$unit" ] || [ -f "/etc/systemd/system/multi-user.target.wants/$unit" ]; then
        mkdir -p "/etc/systemd/system/${unit}.d"
        cat > "/etc/systemd/system/${unit}.d/99-hwaccess-limit.conf" << 'EOF'
[Service]
ExecCondition=
ExecCondition=/bin/sh -c "grep -q 'enable_hw_access=1' /run/droidspaces/container.config"
EOF
    fi
done

if [ -f /etc/logrotate.conf ]; then
    sed -i 's/^#maxsize.*/maxsize 50M/' /etc/logrotate.conf
    if ! grep -q "maxsize 50M" /etc/logrotate.conf; then
        echo "maxsize 50M" >> /etc/logrotate.conf
    fi
fi

echo "Post-extraction fixes applied on $(date)" > /etc/droidspaces
EOF_RUN

COPY scripts/binfmt/qemu-binfmt-register.sh /usr/local/bin/
COPY scripts/binfmt/qemu-binfmt-register.service /etc/systemd/system/
RUN chmod +x /usr/local/bin/qemu-binfmt-register.sh && \
    chmod 644 /etc/systemd/system/qemu-binfmt-register.service && \
    mkdir -p /etc/systemd/system/multi-user.target.wants && \
    ln -sf /etc/systemd/system/qemu-binfmt-register.service /etc/systemd/system/multi-user.target.wants/qemu-binfmt-register.service

RUN if [ "$ENABLE_systemd257_ARG" = "true" ]; then \
        bash /usr/local/sbin/systemd257; \
    else \
        echo "--> [跳过] 未启用 systemd 257 旧内核兼容"; \
    fi

# 最终清理
RUN rm -f \
        /usr/local/sbin/configure-chrome \
        /usr/local/sbin/configure-desktop \
        /usr/local/sbin/install-desktop \
        /usr/local/sbin/install-anland-desktop \
        /usr/local/sbin/install-droidspaces-usb-manager \
        /usr/local/sbin/systemd257 \
        /usr/local/sbin/nosnap && \
    rm -rf /usr/local/lib/droidspaces/desktops && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

FROM scratch AS export
COPY --from=customizer / /
