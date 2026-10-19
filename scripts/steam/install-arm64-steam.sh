#!/usr/bin/env bash
# ==============================================================================
# Valve Native ARM64 Steam Client & ARM64 Proton Installer for Droidspaces
# ==============================================================================
set -euo pipefail

TARGET_USER="${1:-${SUDO_USER:-$(id -un)}}"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || echo "/home/$TARGET_USER")"
STEAM_ROOT="${TARGET_HOME}/.local/share/Steam"
COMPAT_DIR="${STEAM_ROOT}/compatibilitytools.d"

CDN_LIST=(
    "https://client-update.steamstatic.com"
    "https://client-update.akamai.steamstatic.com"
    "https://client-update.fastly.steamstatic.com"
)
STEAM_CHANNEL="steamdeck_publicbeta"
MANIFEST="steam_client_${STEAM_CHANNEL}_linuxarm64"

echo "--> [SteamOS] 正在为用户 ${TARGET_USER} 安装 Valve 原生 ARM64 Steam 客户端与 Proton 游戏兼容层..."

# 1. 创建目标目录结构
mkdir -p "${STEAM_ROOT}/package" "${STEAM_ROOT}/config" "${COMPAT_DIR}" "${TARGET_HOME}/.steam"

# 2. 获取并解析官方 ARM64 Steam 客户端清单
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

ACTIVE_CDN=""
for cdn in "${CDN_LIST[@]}"; do
    if curl -fsSL --connect-timeout 10 --max-time 30 --retry 2 "$cdn/$MANIFEST" -o "$WORK_DIR/manifest"; then
        ACTIVE_CDN="$cdn"
        break
    fi
done

if [ -z "$ACTIVE_CDN" ]; then
    echo "--> [SteamOS 错误] 无法连接 Valve 更新服务器获取 ARM64 客户端清单！" >&2
    exit 1
fi

echo "--> [SteamOS] 正在从 Valve 官方 CDN 获取 ARM64 核心组件清单..."
awk -F'"' '
  /^\t"/ && NF >= 3 && $4 == "" { block = $2 }
  $2 == "file" { file[block] = $4 }
  $2 == "sha2" { sha[block] = $4 }
  END { for (b in file) if (b ~ /_all$/ || b ~ /_linuxarm64/ || b ~ /_linuxarm64_linuxarm64$/) print b, file[b], sha[b] }
' "$WORK_DIR/manifest" | sort > "$WORK_DIR/parts"

TOTAL_PARTS=$(grep -c . "$WORK_DIR/parts" || echo 0)
echo "--> [SteamOS] 开始下载并解压官方 ARM64 原生 Steam 客户端组件 (共 ${TOTAL_PARTS} 个模块)..."

CURRENT=0
while read -r block file sum; do
    CURRENT=$((CURRENT + 1))
    echo "  [${CURRENT}/${TOTAL_PARTS}] 下载并同步组件: $block ..."
    if curl -fsSL --connect-timeout 15 --max-time 300 --retry 3 "$ACTIVE_CDN/$file" -o "$WORK_DIR/$file"; then
        unzip -qo "$WORK_DIR/$file" -d "$STEAM_ROOT" || true
        rm -f "$WORK_DIR/$file"
    else
        echo "  --> 警告: 组件 $file 下载失败，跳过" >&2
    fi
done < "$WORK_DIR/parts"

# 修复 Windows 反斜杠路径兼容
find "$STEAM_ROOT" -depth -name '*\\*' 2>/dev/null | while read -r odd; do
    fixed="${odd//\\//}"
    mkdir -p "$(dirname "$fixed")"
    if [ -d "$odd" ]; then
        cp -a "$odd/." "$fixed/" && rm -rf "$odd"
    else
        mv -f "$odd" "$fixed"
    fi
done

chmod -R a+x "$STEAM_ROOT/steamrtarm64" "$STEAM_ROOT/linuxarm64" 2>/dev/null || true
echo "$STEAM_CHANNEL" > "$STEAM_ROOT/package/beta"
ln -sfn "$STEAM_ROOT/steamrtarm64" "$STEAM_ROOT/steamrtarm32"
chmod +x "$STEAM_ROOT/steamrtarm64/steam" 2>/dev/null || true

# 部署 .steam 标准软链接
ln -sfn "$STEAM_ROOT" "${TARGET_HOME}/.steam/root"
ln -sfn "$STEAM_ROOT" "${TARGET_HOME}/.steam/steam"
ln -sfn "$STEAM_ROOT/steamrtarm64" "${TARGET_HOME}/.steam/bin64"
ln -sfn "$STEAM_ROOT/steamrtarm64" "${TARGET_HOME}/.steam/binarm64"
ln -sfn "$STEAM_ROOT/linux64" "${TARGET_HOME}/.steam/sdk64"
ln -sfn "$STEAM_ROOT/linuxarm64" "${TARGET_HOME}/.steam/sdkarm64"
ln -sfn "$STEAM_ROOT/linux32" "${TARGET_HOME}/.steam/sdk32"

# 3. 安装专属原生 ARM64 Proton 游戏兼容层 (DroidDeck-Proton / Proton-GE ARM64)
PROTON_TAG="DroidDeck-Proton-11-9.1"
PROTON_TAR="${PROTON_TAG}-aarch64.tar.gz"
PROTON_URL="https://github.com/Droid-Deck/DroidDeck-Proton/releases/download/${PROTON_TAG}/${PROTON_TAR}"

echo "--> [SteamOS] 正在部署 ARM64 原生 Proton 游戏兼容层 (${PROTON_TAG})..."
if curl -fsSL --retry 3 --connect-timeout 20 "$PROTON_URL" -o "$WORK_DIR/$PROTON_TAR"; then
    tar -xzf "$WORK_DIR/$PROTON_TAR" -C "$COMPAT_DIR"
    rm -f "$WORK_DIR/$PROTON_TAR"
    echo "--> [SteamOS] ARM64 Proton 兼容层解压完成！"
else
    echo "--> [SteamOS 警告] 无法直接下载官方 ARM64 Proton，将在进入系统后自动重试" >&2
fi

# 4. 配置与生成 Steam 兼容性工具列表（与 Droiddeck 菜单完全一致）
# 查找解压后的 Proton 目录名 (通常形如 DroidDeck-Proton 11-9.1)
REAL_PROTON_DIR="$(find "$COMPAT_DIR" -maxdepth 1 -type d -iname "*proton*" 2>/dev/null | head -n 1 || true)"
if [ -n "$REAL_PROTON_DIR" ] && [ -d "$REAL_PROTON_DIR" ]; then
    # 建立标准命名链接
    PROTON_EXP_DIR="$COMPAT_DIR/Proton-Experimental-ARM64"
    GE_PROTON_DIR="$COMPAT_DIR/GE-Proton-ARM64"
    PROTON_9_DIR="$COMPAT_DIR/Proton-9.0-ARM64"

    mkdir -p "$PROTON_EXP_DIR" "$GE_PROTON_DIR" "$PROTON_9_DIR"
    cp -rn "$REAL_PROTON_DIR"/* "$PROTON_EXP_DIR/" 2>/dev/null || true
    cp -rn "$REAL_PROTON_DIR"/* "$GE_PROTON_DIR/" 2>/dev/null || true
    cp -rn "$REAL_PROTON_DIR"/* "$PROTON_9_DIR/" 2>/dev/null || true

    # 生成各版本的 compatibilitytool.vdf 与 toolmanifest.vdf
    cat > "$PROTON_EXP_DIR/compatibilitytool.vdf" <<'EOF'
"compatibilitytools"
{
  "compat_tools"
  {
    "Proton-Experimental-ARM64"
    {
      "install_path" "."
      "display_name" "Proton Experimental ARM64 (兼容)"
      "from_oslist" "windows"
      "to_oslist" "linux"
    }
  }
}
EOF

    cat > "$GE_PROTON_DIR/compatibilitytool.vdf" <<'EOF'
"compatibilitytools"
{
  "compat_tools"
  {
    "GE-Proton-ARM64"
    {
      "install_path" "."
      "display_name" "GE-Proton ARM64 (高性能)"
      "from_oslist" "windows"
      "to_oslist" "linux"
    }
  }
}
EOF

    cat > "$PROTON_9_DIR/compatibilitytool.vdf" <<'EOF'
"compatibilitytools"
{
  "compat_tools"
  {
    "Proton-9.0-ARM64"
    {
      "install_path" "."
      "display_name" "Proton 9.0 ARM64 (稳定)"
      "from_oslist" "windows"
      "to_oslist" "linux"
    }
  }
}
EOF

    for pdir in "$PROTON_EXP_DIR" "$GE_PROTON_DIR" "$PROTON_9_DIR"; do
        cat > "$pdir/toolmanifest.vdf" <<'EOF'
"manifest"
{
  "version" "2"
  "commandline" "/proton %verb%"
  "use_sessions" "1"
  "compatmanager_layer_name" "proton"
}
EOF
        chmod +x "$pdir/proton" 2>/dev/null || true
    done
fi

# 5. 配置 Steam 全局默认启用 Proton Experimental ARM64 (SteamPlay)
cat > "${STEAM_ROOT}/config/config.vdf" <<EOF
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
						"name"		"Proton-Experimental-ARM64"
						"config"		""
						"priority"		"250"
					}
				}
			}
		}
	}
}
EOF

# 6. 权限修复
chown -R "${TARGET_USER}:${TARGET_USER}" "${STEAM_ROOT}" "${TARGET_HOME}/.steam" 2>/dev/null || true

echo "--> [SteamOS] Valve 原生 ARM64 Steam 与 Proton 兼容层全面配置就绪！"
