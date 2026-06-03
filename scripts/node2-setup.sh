#!/bin/sh
# =============================================================================
#  node2-setup.sh — IEEE 802.11s Mesh Node 2 Configuration Script
#  Project : IoT Mesh Network on TP-Link TL-WA830RE v2
#  Authors : Bouazzi Yanis · Ranem Younes · Aoues Nassim · Yemi Mounir
# =============================================================================
#
#  PREREQUISITES:
#    - firmware-mesh.bin already flashed via sysupgrade -n
#    - Router has rebooted and is reachable at 192.168.1.1
#    - Run this script ON the router via SSH:
#        ssh -o HostKeyAlgorithms=+ssh-rsa root@192.168.1.1
#        sh node2-setup.sh
#
#  WHAT THIS SCRIPT DOES:
#    1. Enables the radio (radio0)
#    2. Sets Wi-Fi mode to 802.11s mesh
#    3. Joins the mesh with ID "Yanis_Mesh"
#    4. Enables mesh forwarding (Layer 2 relay)
#    5. Changes LAN IP to 192.168.1.2 to avoid conflict with Node 1
#    6. Commits and restarts the network
#
#  NOTE: Your SSH session WILL freeze at step 6 — this is expected.
#        The router's IP just changed to 192.168.1.2.
#        Reconnect with: ssh -o HostKeyAlgorithms=+ssh-rsa root@192.168.1.2
# =============================================================================

echo ""
echo "======================================================="
echo "  IEEE 802.11s Mesh — Node 2 Configuration Script"
echo "======================================================="
echo ""

# --- Step 1: Enable radio0 ---
echo "[1/6] Enabling radio0..."
uci set wireless.radio0.disabled='0'

# --- Step 2: Set Wi-Fi mode to mesh ---
echo "[2/6] Setting Wi-Fi mode to 802.11s mesh..."
uci set wireless.default_radio0.mode='mesh'

# --- Step 3: Set mesh network ID ---
echo "[3/6] Setting mesh_id to 'Yanis_Mesh'..."
uci set wireless.default_radio0.mesh_id='Yanis_Mesh'

# --- Step 4: Attach mesh interface to LAN bridge ---
echo "[4/6] Attaching mesh interface to LAN bridge..."
uci set wireless.default_radio0.network='lan'

# --- Step 5: Enable mesh forwarding (Layer 2 relay) ---
echo "[5/6] Enabling mesh forwarding..."
uci set wireless.default_radio0.mesh_fwding='1'

# --- Step 6: Assign unique IP to avoid conflict with Node 1 ---
echo "[6/6] Setting LAN IP to 192.168.1.2 (avoids conflict with Node 1)..."
uci set network.lan.ipaddr='192.168.1.2'

# --- Commit all changes ---
echo ""
echo "Committing UCI configuration..."
uci commit

# --- Apply changes ---
echo "Restarting network services..."
echo "(SSH session will freeze here — reconnect to 192.168.1.2)"
echo ""
/etc/init.d/network restart

# Note: execution won't reach this line via the old SSH session
echo "Done. Reconnect: ssh -o HostKeyAlgorithms=+ssh-rsa root@192.168.1.2"
