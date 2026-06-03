#!/bin/sh
# =============================================================================
#  verify-mesh.sh — Mesh Link Verification Script
#  Project : IoT Mesh Network on TP-Link TL-WA830RE v2
#  Authors : Bouazzi Yanis · Ranem Younes · Aoues Nassim · Yemi Mounir
# =============================================================================
#
#  Run this ON the router after node2-setup.sh has been applied:
#    ssh -o HostKeyAlgorithms=+ssh-rsa root@192.168.1.2
#    sh verify-mesh.sh
#
#  Checks performed:
#    1. Mesh Point capability reported by the driver (iw list)
#    2. Mesh interface is UP and joined (iw dev)
#    3. Peer table — lists all discovered mesh neighbors (iw dev wlan0 mpath)
#    4. Flash/RAM usage summary
# =============================================================================

echo ""
echo "======================================================="
echo "  IEEE 802.11s Mesh — Verification Script"
echo "======================================================="
echo ""

# --- Check 1: Driver capability ---
echo "-------------------------------------------------------"
echo " [1] Driver Mesh Point Capability (iw list)"
echo "-------------------------------------------------------"
iw list | grep -A 10 "Supported interface modes" | grep -i mesh
if [ $? -eq 0 ]; then
    echo "     ✔  Mesh Point supported by driver."
else
    echo "     ✘  Mesh Point NOT found — firmware may be wrong."
fi
echo ""

# --- Check 2: Active mesh interface ---
echo "-------------------------------------------------------"
echo " [2] Active Mesh Interface Status (iw dev)"
echo "-------------------------------------------------------"
iw dev | grep -A 5 "mesh"
echo ""

# --- Check 3: Mesh peer/path table ---
echo "-------------------------------------------------------"
echo " [3] Mesh Peer Table (iw dev wlan0 mpath)"
echo "-------------------------------------------------------"
iw dev wlan0 mpath dump 2>/dev/null
if [ $? -ne 0 ]; then
    echo "     (No mesh paths yet — wait 60s for 802.11s negotiation)"
    echo "     Retry: iw dev wlan0 mpath dump"
fi
echo ""

# --- Check 4: Mesh station info ---
echo "-------------------------------------------------------"
echo " [4] Mesh Station Info (iw dev wlan0 station dump)"
echo "-------------------------------------------------------"
iw dev wlan0 station dump 2>/dev/null | grep -E "Station|signal|tx bitrate|rx bitrate"
echo ""

# --- Check 5: Storage health ---
echo "-------------------------------------------------------"
echo " [5] Flash / Overlay Usage (df -h)"
echo "-------------------------------------------------------"
df -h /overlay /
echo ""

# --- Check 6: Network config summary ---
echo "-------------------------------------------------------"
echo " [6] Network Configuration (uci show network.lan)"
echo "-------------------------------------------------------"
uci show network.lan.ipaddr
uci show wireless.default_radio0.mode
uci show wireless.default_radio0.mesh_id
uci show wireless.default_radio0.mesh_fwding
echo ""

echo "======================================================="
echo "  Verification complete."
echo "  If Check 3 shows a peer, your mesh link is ACTIVE."
echo "======================================================="
echo ""
