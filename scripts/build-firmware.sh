#!/bin/bash
# =============================================================================
#  build-firmware.sh — OpenWrt Image Builder Script (WSL/Ubuntu)
#  Project : IoT Mesh Network on TP-Link TL-WA830RE v2
#  Authors : Bouazzi Yanis · Ranem Younes · Aoues Nassim · Yemi Mounir
# =============================================================================
#
#  USAGE (run inside WSL/Ubuntu):
#    chmod +x build-firmware.sh
#    ./build-firmware.sh
#
#  OUTPUT:
#    firmware-mesh.bin  (in the current directory, copied from Image Builder output)
#
#  WHAT THIS SCRIPT DOES:
#    1. Downloads the OpenWrt Image Builder for ar71xx/tiny (4MB target)
#    2. Bypasses the broken prerequisite checker (Python 2 / old GCC issue)
#    3. Builds a stripped firmware with wpad-mesh, removing everything
#       that doesn't fit: firewall, DHCP, DNS, OPKG, PPP, IPv6
#    4. Copies the output .bin to the current directory
#
#  DEPENDENCIES (install first):
#    sudo apt update && sudo apt install -y build-essential libncurses5-dev \
#         zlib1g-dev gawk git gettext unzip file wget python3 rsync
# =============================================================================

set -e

# --- Configuration ---
OPENWRT_VERSION="19.07.10"
TARGET="ar71xx"
SUBTARGET="tiny"
PROFILE="tl-wa830re-v2"
IB_NAME="openwrt-imagebuilder-${OPENWRT_VERSION}-${TARGET}-${SUBTARGET}.Linux-x86_64"
IB_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/${TARGET}/${SUBTARGET}/${IB_NAME}.tar.xz"

# Packages to INCLUDE
PACKAGES_INCLUDE="wpad-mesh"

# Packages to EXCLUDE (bare metal slimming for 4MB)
PACKAGES_EXCLUDE="-wpad-mini \
    -ppp -kmod-pppoe \
    -firewall -iptables -ip6tables -nftables \
    -odhcpd-ipv6only \
    -dnsmasq \
    -opkg \
    -luci -luci-base"

echo ""
echo "======================================================="
echo "  OpenWrt Image Builder — TP-Link TL-WA830RE v2"
echo "  Target: ${TARGET}/${SUBTARGET} | Profile: ${PROFILE}"
echo "======================================================="
echo ""

# --- Step 1: Download Image Builder ---
if [ ! -d "$IB_NAME" ]; then
    echo "[1/5] Downloading Image Builder (${OPENWRT_VERSION})..."
    wget -c "$IB_URL"
    echo "[1/5] Extracting..."
    tar -xf "${IB_NAME}.tar.xz"
else
    echo "[1/5] Image Builder already extracted, skipping download."
fi

cd "$IB_NAME"

# --- Step 2: Bypass broken prerequisite checker ---
echo ""
echo "[2/5] Bypassing prerequisite checker (Python 2 / GCC version issue)..."
mkdir -p staging_dir/host
touch staging_dir/host/.prereq-build
echo "      Done."

# --- Step 3: Build the firmware ---
echo ""
echo "[3/5] Building firmware with bare-metal slimming..."
echo "      Including : ${PACKAGES_INCLUDE}"
echo "      Excluding : (firewall, DHCP, DNS, PPP, IPv6, opkg, wpad-mini)"
echo ""

make image \
    PROFILE="$PROFILE" \
    PACKAGES="${PACKAGES_INCLUDE} ${PACKAGES_EXCLUDE}" \
    BUILD_LOG=1

# --- Step 4: Locate and copy output ---
echo ""
echo "[4/5] Locating output firmware..."

SYSUPGRADE_BIN=$(find bin/targets/${TARGET}/${SUBTARGET}/ \
    -name "*${PROFILE}*sysupgrade*" 2>/dev/null | head -n 1)

if [ -z "$SYSUPGRADE_BIN" ]; then
    echo "[ERROR] No sysupgrade .bin found. Check build logs in logs/"
    exit 1
fi

echo "      Found: $SYSUPGRADE_BIN"

# --- Step 5: Copy to parent directory ---
echo ""
echo "[5/5] Copying firmware to current directory as 'firmware-mesh.bin'..."
cp "$SYSUPGRADE_BIN" ../firmware-mesh.bin

echo ""
echo "======================================================="
echo "  BUILD SUCCESSFUL"
echo "  Output: firmware-mesh.bin"
echo ""
echo "  Next step (Windows cmd):"
echo "    scp -O -o HostKeyAlgorithms=+ssh-rsa firmware-mesh.bin root@192.168.1.1:/tmp/"
echo "======================================================="
echo ""
