FROM ubuntu:26.04 AS customizer

#######################################################
ARG DESKTOP
ARG DESKTOP_AUTOSTART
ARG PulseAudio
ARG ENABLE_zh_tz_ARG
ARG ENABLE_binfmt_ARG
ARG ENABLE_yj_ARG
ARG ENABLE_mesa_ARG
ARG ENABLE_kfgj_ARG
ARG ENABLE_zip_ARG
ARG ENABLE_docker_ARG
ARG ENABLE_srf_ARG
ARG DISPLAY_BACKEND
ARG ENABLE_8gen2_wayland_ARG
ARG ENABLE_nosnap_ARG
ARG ENABLE_systemd257_ARG
ARG USERNAME
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

# 优先复制自定义脚本
COPY scripts/download-firmware /usr/local/bin/
COPY scripts/nosnap.sh /usr/local/sbin/nosnap
COPY scripts/systemd257.sh /usr/local/sbin/systemd257

# 将自定义的 bashrc 脚本复制到根文件系统的 profile 目录
COPY scripts/bashrc.sh /etc/profile.d/ds-aliases.sh

# 通用 Droidspaces USB Manager 安装器
COPY scripts/install-usb-manager.sh /usr/local/sbin/install-droidspaces-usb-manager
COPY scripts/tui/install-anland-kde.sh /usr/local/sbin/install-anland-kde
COPY scripts/tui/install-anland-gnome.sh /usr/local/sbin/install-anland-gnome
COPY scripts/tui/install-anland-next.sh /usr/local/sbin/install-anland-next
COPY scripts/tui/install-anland-niri.sh /usr/local/sbin/install-anland-niri
COPY scripts/tui/install-anland-hyprland.sh /usr/local/sbin/install-anland-hyprland
COPY scripts/tui/install-anland-mango.sh /usr/local/sbin/install-anland-mango
COPY scripts/tui/install-anland-denial.sh /usr/local/sbin/install-anland-denial
COPY scripts/install-anland-desktop.sh /usr/local/sbin/install-anland-desktop
COPY scripts/tui/install-mesa.sh /usr/local/sbin/install-mesa
COPY scripts/steam/install-arm64-steam.sh /usr/local/sbin/install-arm64-steam
COPY scripts/tui/install-hangover-wine.sh /usr/local/sbin/install-hangover-wine
COPY scripts/tui/install-winefonts.sh /usr/local/sbin/install-winefonts
COPY scripts/tui/droidspaces-tui.sh /usr/local/bin/droidspaces-tui
COPY scripts/install-desktop.sh /usr/local/sbin/install-desktop
COPY scripts/configure-desktop.sh /usr/local/sbin/configure-desktop
COPY scripts/configure-chrome.sh /usr/local/sbin/configure-chrome
COPY scripts/start-desktop-session.sh /usr/local/bin/start-desktop-session
COPY scripts/desktops/ /usr/local/lib/droidspaces/desktops/
COPY scripts/etc/wireplumber/wireplumber.conf.d/Anland-Audio.conf /tmp/Anland-Audio.conf
RUN if [ "$DISPLAY_BACKEND" = "anland-wayland" ]; then \
        install -D -m 0644 /tmp/Anland-Audio.conf /etc/wireplumber/wireplumber.conf.d/Anland-Audio.conf; \
    fi && \
    rm -f /tmp/Anland-Audio.conf

# 赋予相关脚本可执行权限
RUN chmod +x /usr/local/bin/download-firmware /usr/local/sbin/nosnap /etc/profile.d/ds-aliases.sh /usr/local/sbin/install-anland-* /usr/local/sbin/install-mesa /usr/local/sbin/install-hangover-wine /usr/local/sbin/install-winefonts /usr/local/sbin/install-desktop /usr/local/sbin/configure-desktop /usr/local/sbin/configure-chrome /usr/local/bin/droidspaces-tui /usr/local/bin/start-desktop-session /usr/local/lib/droidspaces/desktops/*.sh && \
    ln -s droidspaces-tui /usr/local/bin/dstui && \
    ln -s droidspaces-tui /usr/local/bin/ds-tui

# Ubuntu 基础镜像默认通过 dpkg path-exclude 跳过 .mo 翻译文件；全局放开，
# 保证所有桌面 profile 安装的软件带完整语言翻译。
RUN sed -i 's|^path-exclude=/usr/share/locale/\*/LC_MESSAGES/\*.mo|#&|' \
        /etc/dpkg/dpkg.cfg.d/excludes 2>/dev/null || true

RUN sed -i 's/Components: main/Components: main restricted universe multiverse/g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || \
    sed -i 's/main/main restricted universe multiverse/g' /etc/apt/sources.list 2>/dev/null && \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl wget && \
    if [ "$ENABLE_nosnap_ARG" = "true" ]; then \
        echo "--> [开启] nosnap: 正在预配置并移除 Ubuntu Snap..." && \
        bash /usr/local/sbin/nosnap; \
    else \
        echo "--> [跳过] 未开启 nosnap"; \
    fi && \
    apt-get update && \
    apt-get upgrade -y

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # 核心工具组件
    bash jq dialog coreutils file findutils grep sed gawk curl wget ca-certificates locales bash-completion udev dbus systemd-sysv systemd-resolved fastfetch \
    # 用户请求的基础开发/编辑工具
    git nano sudo \
    # 网络与 SSH 工具
    openssh-server net-tools iptables iputils-ping iproute2 dnsutils \
    # 用于系统监控的 procps 进程工具
    procps \
    # 核心内核模块支持
    kmod tzdata tar mesa-utils vulkan-tools pulseaudio-utils zenity cabextract libevdev2 evtest pciutils usbutils xdg-utils xdg-user-dirs strace binutils libnss3 libnspr4 libasound2* libpulse0 libxss1 libxtst6 libxrandr2 libxcomposite1 libxcursor1 libxdamage1 libxi6 libva2 libopenal1 libxinerama1 libsm6 libice6 && \
    (apt-get install -y libgtk2.0-0t64 || apt-get install -y libgtk2.0-0 || true) && \
    /usr/local/sbin/install-desktop "$DESKTOP" && \
    ############################################## Anland Wayland 支持 ################################################
    if [ "$DISPLAY_BACKEND" = "anland-wayland" ]; then \
        echo "--> [开启] 正在安装 $DESKTOP 的 Anland 包 (${ANLAND_PACKAGE_REVISION})..." && \
        ANLAND_RELEASE_REPOSITORY="$ANLAND_RELEASE_REPOSITORY" \
        /usr/local/sbin/install-anland-desktop "$DESKTOP" --1 && \
        echo "--> [开启] $DESKTOP 的 Anland 支持已安装"; \
    fi && \
    ######################################################################################################
    #输入法 fcitx5 (可选)
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
        docker.io docker-compose-v2; \
    fi && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 强制配置使用 iptables-legacy
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy && \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

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
    # Ubuntu 默认用户是 ubuntu，删除它避免冲突
    (deluser --remove-home ubuntu || true) && \
    # 创建自定义用户并直接加入 shadow 组，确保锁屏验证权限
    useradd -m -s /bin/bash -G shadow ${USERNAME} && echo "${USERNAME}:1234" | chpasswd && \
    systemctl enable ssh

# 为所有 Ubuntu RootFS 安装 Droidspaces USB Manager
RUN /usr/local/sbin/install-droidspaces-usb-manager --user "${USERNAME}"


# 初始化环境变量文件；桌面专属变量由对应 profile 管理。
RUN : > /etc/environment

RUN cat >> /etc/environment <<'EOF'
STEAMOS=1
STEAM_RUNTIME=1
PROTON_USE_WOW64=1
PROTON_USE_NTSYNC=1
EOF

RUN if [ "$ENABLE_mesa_ARG" = "true" ]; then \
        echo 'TURNIP_KMD=kgsl' >> /etc/environment; \
        echo 'VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json' >> /etc/environment; \
        echo 'TU_DEBUG=noconform' >> /etc/environment; \
        echo 'MESA_LOADER_DRIVER_OVERRIDE=kgsl' >> /etc/environment; \
        echo 'GALLIUM_DRIVER=kgsl' >> /etc/environment; \
        echo 'FD_FORCE_KGSL=1' >> /etc/environment; \
    fi

# 修复骁龙8 Gen 2 设备在 Wayland 下的花屏问题
RUN if [ "$ENABLE_8gen2_wayland_ARG" = "true" ]; then \
        echo "FD_DEV_FEATURES=enable_tp_ubwc_flag_hint=1" >> /etc/environment; \
    fi

# 音频选择
RUN if [ "$PulseAudio" = "socket" ]; then \
        echo "PULSE_SERVER=unix:/tmp/.pulse-socket" >> /etc/environment; \
    elif [ "$PulseAudio" = "tcp" ]; then \
        echo "PULSE_SERVER=tcp:127.0.0.1:4713" >> /etc/environment; \
    fi
# 修复anland 音频堵塞
# RUN if [ "$DISPLAY_BACKEND" = "anland-wayland" ]; then \
#        mkdir -p /home/${USERNAME}/.config && \
#       echo -e "\n[Sounds]\nEnable=false" >> /home/${USERNAME}/.config/kdeglobals ; \
#     fi


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
    if [ "$ENABLE_mesa_ARG" = "true" ] && [ "$DISPLAY_BACKEND" != "anland-wayland" ] ; then
        cat <<'EOF' >> /etc/environment
MESA_LOADER_DRIVER_OVERRIDE=kgsl
TU_DEBUG=noconform
EOF
    fi

    echo 'export XDG_RUNTIME_DIR=/run/user/$(id -u)' >> /home/${USERNAME}/.bashrc
    /usr/local/sbin/configure-desktop "$DESKTOP" "$DISPLAY_BACKEND" "$DESKTOP_AUTOSTART" "$USERNAME"
    rm -rf /tmp/droidspaces-start
EOF_RUN

# Mesa 驱动适配
RUN if [ "$ENABLE_mesa_ARG" = "true" ]; then \
        /usr/local/sbin/install-mesa --1; \
    else \
        echo "--> [跳过] 未开启 Mesa 驱动安装"; \
    fi

# 安装并配置原生 ARM64 Google Chrome。
RUN /usr/local/sbin/configure-chrome "$DESKTOP" "$DISPLAY_BACKEND"
# 修复容器内的 DHCP 网络服务配置
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

# 应用 Android 运行环境兼容性修复（重点针对 Systemd 和 Udev）
RUN <<'EOF_RUN'
# --- 1. 常规兼容性修复 ---
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

# --- 2. 针对 Systemd 的特定修复 ---
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
RUN if [ "$ENABLE_binfmt_ARG" = "false" ]; then \
        rm -rf /usr/local/bin/qemu-binfmt-register.sh && \
        rm -rf /etc/systemd/system/qemu-binfmt-register.service ; \
    fi

RUN if [ "$ENABLE_binfmt_ARG" = "true" ]; then \
        chmod +x /usr/local/bin/qemu-binfmt-register.sh && \
        chmod 644 /etc/systemd/system/qemu-binfmt-register.service && \
        mkdir -p /etc/systemd/system/multi-user.target.wants && \
        ln -sf /etc/systemd/system/qemu-binfmt-register.service /etc/systemd/system/multi-user.target.wants/qemu-binfmt-register.service && \
        (apt-get purge -y qemu-* binfmt-support || true) && \
        apt-get autoremove -y && \
        apt-get autoclean && \
        rm -rf /var/lib/binfmts/* /etc/binfmt.d/* /usr/lib/binfmt.d/qemu-* && \
        dpkg --add-architecture amd64 && \
        sed -i '/^Types: deb/a Architectures: arm64' /etc/apt/sources.list.d/ubuntu.sources && \
        printf "Types: deb\nURIs: http://archive.ubuntu.com/ubuntu/\nSuites: resolute resolute-updates resolute-security\nComponents: main universe restricted multiverse\nArchitectures: amd64\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n" > /etc/apt/sources.list.d/ubuntu-amd64.sources && \
        apt-get update && \
        (apt-get install -y --no-install-recommends qemu-user-binfmt libc6:amd64 libc6:arm64 libc-bin || \
         apt-get install -y --no-install-recommends qemu-user-binfmt) && \
        apt-get clean; \
    else \
        rm -f /usr/local/bin/qemu-binfmt-register.sh /etc/systemd/system/qemu-binfmt-register.service; \
    fi

# 可选：为 Ubuntu 26.04 的旧 Android 内核运行环境构建 systemd 257。
RUN if [ "$ENABLE_systemd257_ARG" = "true" ]; then \
        bash /usr/local/sbin/systemd257; \
    else \
        echo "--> [跳过] 未启用 systemd 257 旧内核兼容"; \
    fi

# 打包前删除仅用于构建的一次性脚本；TUI 和运行时脚本保留。
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


# 预创建 Anland 5 socket 软链接与通信目录
RUN <<'EOF_RUN'
mkdir -p /tmp/anland /data/local/tmp /run
ln -sf /run/display.sock /tmp/display_daemon.sock
ln -sf /run/display.sock /tmp/anland/display_daemon.sock
ln -sf /run/display.sock /data/local/tmp/display_daemon.sock

# 针对 Anland 5 高刷屏优化 KWin 合成器配置
mkdir -p "/home/${USERNAME}/.config" /etc/skel/.config
cat > "/home/${USERNAME}/.config/kwinrc" <<'EOF'
[Compositing]
Enabled=true
LatencyPolicy=High
GLCore=true
EOF
cp -f "/home/${USERNAME}/.config/kwinrc" /etc/skel/.config/kwinrc 2>/dev/null || true
EOF_RUN

# 部署 Valve 官方原生 ARM64 Steam 客户端与 ARM64 Proton 安装器
RUN <<'EOF_RUN'
chmod +x /usr/local/sbin/install-arm64-steam
echo "--> [SteamOS] 正在部署 Valve 原生 ARM64 Steam 客户端与 Proton 游戏兼容层..."
/usr/local/sbin/install-arm64-steam "${USERNAME}" || echo "--> [跳过] 离线构建环境中跳过网络下载"
mkdir -p /etc/skel/.steam
ln -fns "/home/${USERNAME}/.local/share/Steam" /etc/skel/.steam/steam
ln -fns "/home/${USERNAME}/.local/share/Steam" /etc/skel/.steam/root
EOF_RUN

# 创建掌机专属 Valve 原生 ARM64 Steam 极速封装器 (自动适配 Wayland 与 X11，直通 Adreno 840)
RUN <<'EOF_RUN'
cat > /usr/local/bin/steam <<'EOF'
#!/usr/bin/env bash
set -e

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
mkdir -p "$XDG_RUNTIME_DIR" /dev/shm 2>/dev/null || true
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
chmod 1777 /dev/shm 2>/dev/null || true

if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -S "$XDG_RUNTIME_DIR/wayland-0" ]; then
    export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
    export GDK_BACKEND="wayland,x11"
    export QT_QPA_PLATFORM="wayland;xcb"
    export SDL_VIDEODRIVER="wayland,x11"
    OZONE="wayland"
else
    export SDL_VIDEODRIVER="x11"
    export GDK_BACKEND="x11"
    export QT_QPA_PLATFORM="xcb"
    OZONE="x11"
fi

# 确保 Xwayland/X11 的 DISPLAY 始终有效 (Steam 客户端更新窗口为传统 GTK2/X11 程序，必须通过 XOpenDisplay 渲染)
if [ -z "${DISPLAY:-}" ]; then
    for x in /tmp/.X11-unix/X*; do
        if [ -S "$x" ]; then
            num="${x##*/X}"
            export DISPLAY=":$num"
            break
        fi
    done
    export DISPLAY="${DISPLAY:-:0}"
fi

export PULSE_SERVER="${PULSE_SERVER:-unix:/tmp/.pulse-socket}"
export PULSE_LATENCY_MSEC="${PULSE_LATENCY_MSEC:-20}"
export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-pulse}"

# 性能与高通 Adreno 核显 (Turnip + KGSL + Zink) 强制直通
export TURNIP_KMD="kgsl"
export VK_ICD_FILENAMES="/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json"
export TU_DEBUG="noconform"
export MESA_LOADER_DRIVER_OVERRIDE="kgsl"
export GALLIUM_DRIVER="kgsl"
export FD_FORCE_KGSL=1

export STEAMOS=1
export STEAM_RUNTIME=1
export DBUS_FATAL_WARNINGS=0
export MESA_VK_WSI_PRESENT_MODE=mailbox

CEF_FLAGS=(
    -no-cef-sandbox
    "-cef-ozone-platform=${OZONE}"
    -cef-enable-gpu-rasterization
    -cef-ignore-gpu-blocklist
    --no-sandbox
    --no-zygote
    --disable-gpu-sandbox
    --in-process-gpu
)

STEAM_ROOT="${HOME}/.local/share/Steam"
if [ ! -x "$STEAM_ROOT/steamrtarm64/steam" ]; then
    echo "--> [SteamOS] 正在部署 Valve 官方 ARM64 原生 Steam 客户端与 Proton 游戏兼容层..."
    /usr/local/sbin/install-arm64-steam || true
fi

if [ -x "$STEAM_ROOT/steamrtarm64/steam" ]; then
    cd "$STEAM_ROOT/steamrtarm64"
    export LD_LIBRARY_PATH="$STEAM_ROOT/steamrtarm64:$STEAM_ROOT/steamrtarm64/panorama${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    if [ $# -eq 0 ]; then
        set -- "${CEF_FLAGS[@]}" -gamepadui -fullscreen -steamos3
    else
        set -- "${CEF_FLAGS[@]}" "$@"
    fi
    echo "--> [SteamOS] 启动 Valve 原生 ARM64 Steam 客户端..."
    exec "$STEAM_ROOT/steamrtarm64/steam" "$@"
fi

echo "--> [SteamOS] 错误：未找到 ARM64 原生客户端，请在终端执行 'install-arm64-steam' 安装！" >&2
exit 1
EOF
chmod +x /usr/local/bin/steam
ln -sf /usr/local/bin/steam /usr/local/bin/steamos-session
EOF_RUN

# 配置桌面图标、快捷方式与 Steam Deck Gamepad UI 自动启动
RUN <<'EOF_RUN'
mkdir -p /usr/share/applications "/home/${USERNAME}/Desktop" "/home/${USERNAME}/.config/autostart" /etc/skel/Desktop /etc/skel/.config/autostart /etc/xdg/autostart

cat > /usr/share/applications/steam.desktop <<'EOF'
[Desktop Entry]
Name=Steam
Comment=Application for managing and playing games on Steam
Exec=/usr/local/bin/steam %U
Icon=steam
Terminal=false
Type=Application
Categories=Network;FileTransfer;Game;
MimeType=x-scheme-handler/steam;x-scheme-handler/steamlink;
EOF

cat > /usr/share/applications/steam-gamepadui.desktop <<'EOF'
[Desktop Entry]
Name=Steam Deck Gamepad UI
Comment=Start Steam in Handheld Big Picture Gamepad UI Mode
Exec=/usr/local/bin/steam -gamepadui -fullscreen -steamos3
Icon=steam
Terminal=false
Type=Application
Categories=Game;
EOF

cp -f /usr/share/applications/steam*.desktop "/home/${USERNAME}/Desktop/"
cp -f /usr/share/applications/steam-gamepadui.desktop "/home/${USERNAME}/.config/autostart/"
cp -f /usr/share/applications/steam-gamepadui.desktop /etc/xdg/autostart/
cp -f /usr/share/applications/steam*.desktop /etc/skel/Desktop/ 2>/dev/null || true
cp -f /usr/share/applications/steam-gamepadui.desktop /etc/skel/.config/autostart/ 2>/dev/null || true
chmod +x "/home/${USERNAME}/Desktop/"*.desktop 2>/dev/null || true
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/Desktop" "/home/${USERNAME}/.config" 2>/dev/null || true
EOF_RUN

FROM scratch AS export
COPY --from=customizer / /
