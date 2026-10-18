FROM ogarcia/archlinux AS customizer

#######################################################
ARG DESKTOP=kde
ARG DESKTOP_AUTOSTART=true
ARG PulseAudio=socket
ARG ENABLE_zh_tz_ARG=true
ARG ENABLE_binfmt_ARG=true
ARG ENABLE_yj_ARG=true
ARG ENABLE_mesa_ARG=true
ARG DISPLAY_BACKEND=anland-wayland
ARG ENABLE_8gen2_wayland_ARG=false
ARG ENABLE_kfgj_ARG=true
ARG ENABLE_zip_ARG=true
ARG ENABLE_docker_ARG=false
ARG ENABLE_srf_ARG=true
ARG ENABLE_systemd257_ARG=false
ARG USERNAME=deck
ARG ANLAND_RELEASE_REPOSITORY=Goldzxcbug/droidspaces-package
ARG ANLAND_PACKAGE_REVISION=unknown
######################################################

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
COPY scripts/tui/install-hangover-wine.sh /usr/local/sbin/install-hangover-wine
COPY scripts/tui/install-winefonts.sh /usr/local/sbin/install-winefonts
COPY scripts/tui/droidspaces-tui.sh /usr/local/bin/droidspaces-tui
COPY scripts/install-desktop.sh /usr/local/sbin/install-desktop
COPY scripts/configure-desktop.sh /usr/local/sbin/configure-desktop
COPY scripts/configure-chrome.sh /usr/local/sbin/configure-chrome
COPY scripts/start-desktop-session.sh /usr/local/bin/start-desktop-session
COPY scripts/desktops/ /usr/local/lib/droidspaces/desktops/
COPY scripts/etc/wireplumber/wireplumber.conf.d/Anland-Audio.conf /tmp/Anland-Audio.conf

# 注入 SteamOS 游戏与 Steam 专属工具
COPY scripts/steam/install-steam.sh /usr/local/sbin/install-steam
COPY scripts/steam/steam.sh /usr/local/bin/steam
COPY scripts/steam/steamos-session.sh /usr/local/bin/steamos-session
COPY scripts/steam/steamos-gamemode.sh /usr/local/bin/steamos-gamemode
COPY scripts/steam/steam.desktop /usr/share/applications/steam.desktop
COPY scripts/steam/steam-gamepadui.desktop /usr/share/applications/steam-gamepadui.desktop
COPY scripts/steam/install-steam.desktop /usr/share/applications/install-steam.desktop
COPY scripts/steam/steam.svg /usr/share/icons/hicolor/scalable/apps/steam.svg

RUN if [ "$DISPLAY_BACKEND" = "anland-wayland" ]; then \
        install -D -m 0644 /tmp/Anland-Audio.conf /etc/wireplumber/wireplumber.conf.d/Anland-Audio.conf; \
    fi && \
    rm -f /tmp/Anland-Audio.conf

RUN chmod +x /usr/local/sbin/install-anland-* /usr/local/sbin/install-mesa /usr/local/sbin/install-hangover-wine /usr/local/sbin/install-winefonts /usr/local/sbin/install-desktop /usr/local/sbin/configure-desktop /usr/local/sbin/configure-chrome /usr/local/bin/droidspaces-tui /usr/local/bin/start-desktop-session /usr/local/lib/droidspaces/desktops/*.sh && \
    chmod +x /usr/local/sbin/install-steam /usr/local/bin/steam /usr/local/bin/steamos-session /usr/local/bin/steamos-gamemode && \
    ln -s droidspaces-tui /usr/local/bin/dstui && \
    ln -s droidspaces-tui /usr/local/bin/ds-tui && \
    sed -i '/^#ParallelDownloads/s/^#//' /etc/pacman.conf && \
    sed -i '/NoExtract.*locale/d' /etc/pacman.conf && \
    sed -i '/NoExtract.*i18n/d' /etc/pacman.conf && \
    pacman -Sy --noconfirm archlinux-keyring glibc && \
    pacman -Su --noconfirm && \
    pacman -S --noconfirm --needed \
    # 核心工具组件
    bash jq dialog coreutils file findutils grep sed gawk curl wget ca-certificates bash-completion dbus systemd pam fastfetch logrotate \
    # 用户请求的基础开发/编辑工具
    git nano sudo \
    # 网络与 SSH 工具
    openssh net-tools iptables iputils iproute2 bind \
    # 用于系统监控的 procps 进程工具
    procps-ng \
    # 核心内核模块支持
    kmod tzdata tar \
    # SteamOS 游戏与图形运行库支持
    gamescope mesa-utils vulkan-icd-loader vulkan-tools vkmark \
    sdl2 sdl2_image sdl2_mixer sdl2_ttf openal \
    pipewire pipewire-alsa pipewire-pulse wireplumber libpulse alsa-lib alsa-utils \
    libevdev evtest cabextract zenity pciutils usbutils xdg-utils xdg-user-dirs strace binutils && \
    /usr/local/sbin/install-desktop "$DESKTOP" && \
    # 输入法 fcitx5 (可选)
    if [ "$ENABLE_srf_ARG" = "true" ]; then \
        pacman -S --noconfirm --needed fcitx5-im; \
    fi && \
    if [ "$ENABLE_srf_ARG" = "true" ] && [ "$ENABLE_zh_tz_ARG" = "true" ]; then \
        pacman -S --noconfirm --needed fcitx5-chinese-addons; \
    fi && \
    ## 开发工具集成 (可选)
    if [ "$ENABLE_kfgj_ARG" = "true" ]; then \
        pacman -S --noconfirm --needed \
        base-devel cmake clang llvm python python-pip; \
    fi && \
    ## 压缩工具扩展 (可选)
    if [ "$ENABLE_zip_ARG" = "true" ]; then \
        pacman -S --noconfirm --needed \
        zip unzip p7zip bzip2 xz tar gzip; \
    fi && \
    ## docker (可选)
    if [ "$ENABLE_docker_ARG" = "true" ]; then \
        pacman -S --noconfirm --needed \
        docker docker-compose; \
    fi

# 启用 Anland 时从固定滚动 GitHub Release 安装对应桌面的 ARM64 包。
RUN if [ "$DISPLAY_BACKEND" = "anland-wayland" ]; then \
        echo "--> [enabled] Installing Anland $DESKTOP packages (${ANLAND_PACKAGE_REVISION})..." && \
        ANLAND_RELEASE_REPOSITORY="$ANLAND_RELEASE_REPOSITORY" \
        ANLAND_NIRI_RELEASE_REPOSITORY="$ANLAND_RELEASE_REPOSITORY" \
        /usr/local/sbin/install-anland-desktop "$DESKTOP" --1 && \
        echo "--> [enabled] Anland $DESKTOP support installed"; \
    fi

# 设置 SteamOS 发行版身份与版本标识
RUN cat > /etc/os-release <<'EOF'
NAME="SteamOS"
PRETTY_NAME="SteamOS 3 (Holo - Droidspaces Edition)"
ID=steamos
ID_LIKE=arch
BUILD_ID="rolling"
ANSI_COLOR="1;35"
HOME_URL="https://store.steampowered.com/steamos"
DOCUMENTATION_URL="https://github.com/GuoDong999/Droidspaces-rootfs-Desktop-builder"
SUPPORT_URL="https://github.com/GuoDong999/Droidspaces-rootfs-Desktop-builder/issues"
BUG_REPORT_URL="https://github.com/GuoDong999/Droidspaces-rootfs-Desktop-builder/issues"
LOGO=steamos
VARIANT="Steam Deck & Handheld Gaming"
VARIANT_ID=steamdeck
STEAMOS=1
EOF
RUN cp -f /etc/os-release /usr/lib/os-release 2>/dev/null || true && \
    echo "3.6.0-droidspaces" > /etc/steamos-version && \
    echo "SteamOS 3 (Holo) \n \l" > /etc/issue && \
    echo "SteamOS 3 (Holo) %h" > /etc/issue.net

# 配置 Locale 与 SSH 及默认用户 (默认为 deck 用户)
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    if [ "$ENABLE_zh_tz_ARG" = "true" ]; then \
        ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
        echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gen && \
        locale-gen && \
        echo "LANG=zh_CN.UTF-8" > /etc/locale.conf && \
        echo "LC_ALL=zh_CN.UTF-8" >> /etc/locale.conf; \
    else \
        locale-gen && \
        echo "LANG=en_US.UTF-8" > /etc/locale.conf && \
        echo "LC_ALL=en_US.UTF-8" >> /etc/locale.conf; \
    fi && \
    # 配置 SSH 服务
    mkdir -p /var/run/sshd && \
    ssh-keygen -A && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    (userdel -r alarm 2>/dev/null || true) && \
    useradd -m -s /bin/bash ${USERNAME} && echo "${USERNAME}:1234" | chpasswd && \
    systemctl enable sshd

# 为 SteamOS RootFS 安装 Droidspaces USB Manager
RUN /usr/local/sbin/install-droidspaces-usb-manager --user "${USERNAME}"

# 禁用会导致非 Gamescope 独立环境弹窗报错的 Gamescope WSI 隐式 Vulkan 图层
RUN rm -f /usr/share/vulkan/implicit_layer.d/*gamescope_wsi*.json /usr/share/vulkan/explicit_layer.d/*gamescope_wsi*.json 2>/dev/null || true

# 预安装 Hangover Wine 与字体 (支持 x86/x64 Windows 游戏运行)
RUN echo "--> [SteamOS] 预安装 Hangover Wine 运行环境..." && \
    /usr/local/sbin/install-hangover-wine --1 || echo "--> [跳过] 离线构建环境中跳过 Hangover 下载"
RUN echo "--> [SteamOS] 预安装游戏字体..." && \
    /usr/local/sbin/install-winefonts --1 || echo "--> [跳过] 离线构建环境中跳过字体下载"

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

# 预下载 Steam 官方 Windows 安装包（用于 Hangover Wine 一键初始化）
RUN mkdir -p /usr/local/share/steam && \
    (curl -fsSL --retry 3 --connect-timeout 20 "https://cdn.fastly.steamstatic.com/client/installer/SteamSetup.exe" -o /usr/local/share/steam/SteamSetup.exe || \
     curl -fsSL --retry 3 --connect-timeout 20 "https://media.steampowered.com/client/installer/SteamSetup.exe" -o /usr/local/share/steam/SteamSetup.exe || true)

# 配置桌面图标、快捷方式与 Steam Deck 大屏模式自动启动（全局 XDG autostart 与用户目录）
RUN mkdir -p /home/${USERNAME}/Desktop /home/${USERNAME}/.config/autostart /etc/skel/Desktop /etc/skel/.config/autostart /etc/xdg/autostart && \
    cp -f /usr/share/applications/steam.desktop /home/${USERNAME}/Desktop/ && \
    cp -f /usr/share/applications/steam-gamepadui.desktop /home/${USERNAME}/Desktop/ && \
    cp -f /usr/share/applications/install-steam.desktop /home/${USERNAME}/Desktop/ && \
    cp -f /usr/share/applications/steam-gamepadui.desktop /home/${USERNAME}/.config/autostart/steam-gamepadui.desktop && \
    cp -f /usr/share/applications/steam-gamepadui.desktop /etc/xdg/autostart/steam-gamepadui.desktop && \
    cp -f /usr/share/applications/steam*.desktop /etc/skel/Desktop/ 2>/dev/null || true && \
    cp -f /usr/share/applications/steam-gamepadui.desktop /etc/skel/.config/autostart/ 2>/dev/null || true && \
    chmod +x /home/${USERNAME}/Desktop/*.desktop 2>/dev/null || true

# 为 droidspaces 的 su/su -l 入口建立完整的 systemd 用户会话。
RUN for pam_file in /etc/pam.d/su /etc/pam.d/su-l; do \
        if ! grep -qE '^[[:space:]-]*session[[:space:]].*pam_systemd\.so' "$pam_file"; then \
            sed -i '/^[[:space:]]*session[[:space:]].*pam_unix\.so/a\session        optional        pam_systemd.so' "$pam_file"; \
        fi; \
    done && \
    grep -qE '^[[:space:]]*session[[:space:]].*pam_env\.so' /etc/pam.d/su-l || \
        echo 'session        required        pam_env.so' >> /etc/pam.d/su-l

# 初始化环境变量文件
RUN : > /etc/environment
# 音频选择
RUN if [ "$PulseAudio" = "socket" ]; then \
        echo "PULSE_SERVER=unix:/tmp/.pulse-socket" >> /etc/environment; \
    elif [ "$PulseAudio" = "tcp" ]; then \
        echo "PULSE_SERVER=tcp:127.0.0.1:4713" >> /etc/environment; \
    fi

RUN if [ "$ENABLE_mesa_ARG" = "true" ] && [ "$DISPLAY_BACKEND" = "anland-wayland" ]; then \
        echo 'MESA_LOADER_DRIVER_OVERRIDE=kgsl' >> /etc/environment; \
        echo 'GALLIUM_DRIVER=kgsl' >> /etc/environment; \
        echo 'FD_FORCE_KGSL=1' >> /etc/environment; \
        echo 'TURNIP_KMD=kgsl' >> /etc/environment; \
        echo 'TU_DEBUG=noconform' >> /etc/environment; \
        echo 'FD_DEV_FEATURES=enable_tp_ubwc_flag_hint=1' >> /etc/environment; \
        echo 'ANLAND_SKIP_IMPLICIT_SYNC_WAIT=1' >> /etc/environment; \
        echo 'ANLAND_PRESENT_BACKEND=legacy' >> /etc/environment; \
        echo 'KWIN_WAYLAND_NO_IMPLICIT_SYNC=1' >> /etc/environment; \
        echo 'KWIN_DRM_NO_DIRECT_SCANOUT=1' >> /etc/environment; \
        echo 'MESA_VK_WSI_PRESENT_MODE=mailbox' >> /etc/environment; \
    fi

RUN if [ "$ENABLE_8gen2_wayland_ARG" = "true" ]; then \
        echo 'FD_DEV_FEATURES=enable_tp_ubwc_flag_hint=1' >> /etc/environment; \
    fi

# 写入 SteamOS 专属游戏优化环境变量（注：MANGOHUD / STEAM_RUNTIME 等应用级变量在 steam.sh 与 steamos-gamemode.sh 中按需加载，不可注入全局环境以免导致合成器 kwin 崩溃）
RUN cat >> /etc/environment <<'EOF'
STEAMOS=1
PROTON_USE_WOW64=1
PROTON_USE_NTSYNC=1
EOF

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

# 下载并安装 Mesa
RUN if [ "$ENABLE_mesa_ARG" = "true" ]; then \
        /usr/local/sbin/install-mesa --1; \
    else \
        echo "--> [跳过] 未开启 Mesa 驱动安装"; \
    fi

# 安装并配置原生 ARM64 Google Chrome
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
# 建立 Android 网络权限组
grep -q '^aid_inet:' /etc/group     || echo 'aid_inet:x:3003:'    >> /etc/group
grep -q '^aid_net_raw:' /etc/group || echo 'aid_net_raw:x:3004:' >> /etc/group
grep -q '^aid_net_admin:' /etc/group || echo 'aid_net_admin:x:3005:' >> /etc/group

# 检查并创建 droidspaces-gpu 组
getent group droidspaces-gpu >/dev/null || groupadd -g 786 -r droidspaces-gpu
# 为 root 用户赋予访问 Android 硬件及网络的权限组
usermod -a -G aid_inet,aid_net_raw,input,video,tty,droidspaces-gpu root || true
usermod -a -G aid_inet,aid_net_raw,input,video,tty,wheel,droidspaces-gpu ${USERNAME} || true

# 确保 Arch 赋予 sudo 权限给 wheel 组
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# --- 2. 针对 Systemd 的特定修复 ---
ln -sf /dev/null /etc/systemd/system/systemd-networkd-wait-online.service
ln -sf /dev/null /etc/systemd/system/systemd-journald-audit.socket

# 优化 Journald 日志配置
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
GUEST_SYSTEMD_PATH="/usr/lib/systemd/system"

if [ -f "$GUEST_SYSTEMD_PATH/dbus.service" ]; then
    ln -sf "$GUEST_SYSTEMD_PATH/dbus.service" "/etc/systemd/system/multi-user.target.wants/dbus.service"
fi

if [ "$ENABLE_yj_ARG" = "true" ]; then
    for service in systemd-udevd.service systemd-resolved.service systemd-networkd.service NetworkManager.service; do
        if [ -f "$GUEST_SYSTEMD_PATH/$service" ]; then
            ln -sf "$GUEST_SYSTEMD_PATH/$service" "/etc/systemd/system/multi-user.target.wants/$service";
        fi
    done
else
    for service in systemd-udevd.service systemd-resolved.service systemd-networkd.service NetworkManager.service; do
        ln -sf /dev/null "/etc/systemd/system/$service"
    done
fi

# 在 systemd-logind 中禁用电源键行为处理
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/99-power-key.conf << 'EOF'
[Login]
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandlePowerKeyLongPress=ignore
HandlePowerKeyLongPressHibernate=ignore
EOF

# 应用 udev 覆盖配置
mkdir -p /etc/systemd/system/systemd-udev-trigger.service.d
cat > /etc/systemd/system/systemd-udev-trigger.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/udevadm trigger --subsystem-match=usb --subsystem-match=block --subsystem-match=input --subsystem-match=tty --subsystem-match=net
EOF

# 针对只读文件系统路径覆盖
for unit in systemd-udevd.service systemd-udev-trigger.service systemd-udev-settle.service systemd-udevd-kernel.socket systemd-udevd-control.socket; do
    mkdir -p "/etc/systemd/system/${unit}.d"
    printf "[Unit]\nConditionPathIsReadWrite=\n" > "/etc/systemd/system/${unit}.d/99-readonly-fix.conf"
done

# 屏蔽在 Android 容器中缺少硬件导致 D-Bus 超时阻塞桌面启动的守护进程
for unit in upower.service ModemManager.service power-profiles-daemon.service rtkit-daemon.service; do
    ln -sf /dev/null "/etc/systemd/system/$unit"
done
mkdir -p /etc/dbus-1/system-services.disabled
for dbus_svc in org.freedesktop.UPower.service org.freedesktop.ModemManager1.service; do
    if [ -f "/usr/share/dbus-1/system-services/$dbus_svc" ]; then
        mv "/usr/share/dbus-1/system-services/$dbus_svc" /etc/dbus-1/system-services.disabled/ 2>/dev/null || true
    fi
done

# 预创建 Anland socket 软链接与通信目录
mkdir -p /tmp/anland /data/local/tmp
ln -sf /run/display.sock /tmp/display_daemon.sock
ln -sf /run/display.sock /tmp/anland/display_daemon.sock
ln -sf /run/display.sock /data/local/tmp/display_daemon.sock

# 限制特定的网络服务
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

# 仅在启用硬件访问时限制 udev 服务启动
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

# 针对 Android 环境微调日志轮转
if [ -f /etc/logrotate.conf ]; then
    sed -i 's/^#maxsize.*/maxsize 50M/' /etc/logrotate.conf
    if ! grep -q "maxsize 50M" /etc/logrotate.conf; then
        echo "maxsize 50M" >> /etc/logrotate.conf
    fi
fi

chown -R ${USERNAME}:${USERNAME} /home/${USERNAME} 2>/dev/null || true
echo "SteamOS RootFS build completed on $(date)" > /etc/droidspaces
EOF_RUN

# 注入 binfmt 服务脚本 (支持 x86/x64 跨架构运行)
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
        pacman -S --noconfirm --needed qemu-user qemu-user-binfmt && \
        rm -rf /var/cache/pacman/pkg/* /var/lib/pacman/sync/* ; \
    else \
        rm -f /usr/local/bin/qemu-binfmt-register.sh /etc/systemd/system/qemu-binfmt-register.service; \
    fi

# 可选：为 systemd 258+ 发行版构建 systemd 257 旧内核兼容运行时。
RUN if [ "$ENABLE_systemd257_ARG" = "true" ]; then \
        bash /usr/local/sbin/systemd257; \
    else \
        echo "--> [跳过] 未启用 systemd 257 旧内核兼容"; \
    fi

# 清理 pacman 缓存与一次性脚本
RUN rm -f \
        /usr/local/sbin/configure-chrome \
        /usr/local/sbin/configure-desktop \
        /usr/local/sbin/install-desktop \
        /usr/local/sbin/install-anland-desktop \
        /usr/local/sbin/install-droidspaces-usb-manager \
        /usr/local/sbin/systemd257 \
        /usr/local/sbin/nosnap && \
    rm -rf /usr/local/lib/droidspaces/desktops && \
    rm -rf /var/cache/pacman/pkg/* /var/lib/pacman/sync/*

# 阶段 2：将完整的根文件系统导出到 scratch
FROM scratch AS export
COPY --from=customizer / /
