
<div align="center">

#  IEEE 802.11s Mesh Network — IoT Deployment
### *Turning a 4 MB router into a fully functional mesh node*

![OpenWrt](https://img.shields.io/badge/OpenWrt-00B5E2?style=for-the-badge&logo=openwrt&logoColor=white)
![IEEE 802.11s](https://img.shields.io/badge/IEEE_802.11s-Mesh-brightgreen?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-TP--Link_TL--WA830RE_v2-red?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Completed-success?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

**Project · Internet of Things · 4th Year Engineering — Advanced Telecommunications**

*Bouazzi Yanis · Ranem Younes · Aoues Nassim · Yemi Mounir*

---

</div>

## Table of Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [The Challenge](#the-challenge)
- [Architecture](#architecture)
- [Protocol Choice](#protocol-choice)
- [Methodology](#methodology)
- [Node 2 Setup Guide](#node-2-setup-guide)
- [Feasibility: OpenWrt on PC](#feasibility-openwrt-on-pc)
- [Results & Validation](#results--validation)
- [Scripts Reference](#scripts-reference)
- [References](#references)

---

##  Overview

This project demonstrates that **advanced mesh networking is achievable even on the most constrained hardware**. Starting from a TP-Link TL-WA830RE v2 — a home repeater with only **4 MB of Flash** — we engineered a custom OpenWrt firmware that implements the **IEEE 802.11s mesh standard**, turning obsolete hardware into a reliable IoT relay node.

 **Key result:** A fully functional 802.11s Mesh Point, verified via `iw list`, deployed on hardware with zero available overlay space — achieved through bare-metal firmware recompilation.
---
 
##  Requirements
 
Everything you need is :
 
###  Windows PC (host machine)
 
| Requirement | Version / Notes |
|---|---|
| **Windows** | 10 or 11 (64-bit) |
| **OpenSSH Client** | Built-in since Windows 10 v1809 — verify with `ssh -V` in CMD |
| **WSL 2** | Windows Subsystem for Linux — [install guide](https://learn.microsoft.com/en-us/windows/wsl/install) |
| **Ubuntu on WSL** | 20.04 LTS or 22.04 LTS (recommended) |
| **Ethernet port or USB adapter** | Required to connect directly to the router |
 
 To check if OpenSSH is installed: open CMD and run `ssh -V`. You should see something like `OpenSSH_for_Windows_8.x`.
 
 
---
 
###  Inside WSL / Ubuntu
 
Install all build dependencies before running `build-firmware.sh`:
 
```bash
sudo apt update && sudo apt install -y \
    build-essential libncurses5-dev zlib1g-dev \
    gawk git gettext unzip file wget python3 rsync
```
 
| Package | Min version | Purpose |
|---|---|---|
| `build-essential` | any | GCC, make, core build tools |
| `libncurses5-dev` | any | Required by OpenWrt menuconfig |
| `zlib1g-dev` | any | Compression library |
| `gawk` | 4.x+ | OpenWrt build scripts |
| `git` | 2.x+ | Source fetching |
| `wget` | any | Image Builder download |
| `python3` | 3.6+ | Replaces broken Python 2 requirement |
| `rsync` | any | File staging |
 
---
 
###  Hardware
 
| Item | Specification |
|---|---|
| **Router × 2** | TP-Link TL-WA830RE **v2** (not v1 — different flash layout) |
| **Ethernet cable** | Standard RJ45, for PC ↔ router connection during flash |
| **USB-to-Ethernet adapter** | Only if your PC has no physical Ethernet port |
 
 

---

##  The Challenge

| Constraint | Value | Impact |
|---|---|---|
| Flash Memory | **4 MB** | Virtually no room for packages |
| RAM | **32 MB** | No room for heavy services |
| Overlay free space | **68 KB** | `opkg install` physically impossible |
| Target package | `wpad-mesh` | Not in stock firmware |

The standard approach — using `opkg` to swap `wpad-mini` for `wpad-mesh` — was **completely impossible**. The SquashFS partition is read-only; removing a factory package doesn't free space, it just writes a masking rule to the already-full overlay, making things *worse*.

This forced us to rethink from scratch.

---

##  Architecture

```
                        ┌─────────────────────────────────┐
                        │     IoT Sensor Infrastructure    │
                        └──────────────┬──────────────────┘
                                       │
          ┌────────────────────────────▼────────────────────────────┐
          │                   IEEE 802.11s Mesh                      │
          │                                                          │
          │   ┌──────────────────┐   Radio   ┌──────────────────┐   │
          │   │  TP-Link Node 1  │◄─────────►│  TP-Link Node 2  │   │
          │   │  (Mesh Point)    │  802.11s  │  (Mesh Point)    │   │
          │   │  IP: 192.168.1.1 │           │  IP: 192.168.1.2 │   │
          │   └──────────────────┘           └──────────────────┘   │
          │                                                          │
          │             [Optional Extension]                         │
          │   ┌──────────────────────────────────────────────────┐  │
          │   │     PC under OpenWrt x86 (Mesh Portal Point)     │  │
          │   │  MQTT Broker · Sensor DB · Gateway to Internet   │  │
          │   └──────────────────────────────────────────────────┘  │
          └──────────────────────────────────────────────────────────┘
```

The protocol operates at **Layer 2**, meaning the mesh is completely transparent to IP — devices on either node are on the same broadcast domain with no routing complexity.

---

##  Protocol Choice

Two major mesh protocols were evaluated:

| Criterion | B.A.T.M.A.N. Advanced | **IEEE 802.11s ** |
|---|---|---|
| Layer | Layer 2 | Layer 2 (MAC) |
| Implementation | External kernel module + `batctl` daemon | Native in Wi-Fi driver |
| Storage footprint | **Too large** (exceeds 4 MB budget) | Minimal (grafts onto existing `ath9k` driver) |
| External dependencies | `kmod-batman-adv`, `batctl` | `wpad-mesh` only |
| Verdict |  Rejected |  **Selected** |

**802.11s was chosen** because it is built directly into the Wi-Fi MAC layer, requiring no external routing daemon — a decisive advantage when every kilobyte counts.

---

##  Methodology

### Step 1 — Audit the Storage Reality

```bash
df -h /overlay
# Result: 68K available — opkg is dead on arrival
```

### Step 2 — Deploy the OpenWrt Image Builder (WSL/Ubuntu)

```bash
# Download the ar71xx/tiny branch — the only one targeting 4 MB devices
wget https://downloads.openwrt.org/releases/[version]/targets/ar71xx/tiny/openwrt-imagebuilder-*.tar.xz
tar -xf openwrt-imagebuilder-*.tar.xz
cd openwrt-imagebuilder-*/
```

### Step 3 — Extreme Slimming: Remove Everything Non-Essential

To fit `wpad-mesh` into 4 MB, we surgically removed services irrelevant to a pure Layer-2 relay:

```bash
make image \
  PROFILE="tl-wa830re-v2" \
  PACKAGES="-wpad-mini wpad-mesh \
            -ppp -kmod-pppoe \
            -firewall -iptables -ip6tables \
            -odhcpd-ipv6only \
            -dnsmasq \
            -opkg"
```

 **Why remove `opkg` itself?** Once the flash is 100% full, the package manager serves no purpose and wastes space.

### Step 4 — Bypass the Broken Build Script

The 2018-era Image Builder failed under modern Ubuntu, looking for Python 2.x and old GCC:

```bash
# Trick the prerequisite checker
touch staging_dir/host/.prereq-build
# Force the build
make image [PACKAGES=...] BUILD_LOG=1
```

### Step 5 — Flash via SCP + SSH

Windows' modern `scp` defaults to SFTP, which the router's minimal Dropbear SSH doesn't support:

```bash
# -O flag forces legacy SCP protocol
scp -O -o HostKeyAlgorithms=+ssh-rsa firmware-mesh.bin root@192.168.1.1:/tmp/

# Connect and flash
ssh -o HostKeyAlgorithms=+ssh-rsa root@192.168.1.1
sysupgrade -n /tmp/firmware-mesh.bin
```

### Step 6 — Verify

```bash
iw list | grep -A5 "Supported interface modes"
# Expected output: * mesh point
```

---

##  Node 2 Setup Guide

 **Prerequisites:** `firmware-mesh.bin` compiled and ready, first router powered **off**.

### Phase 1 — Flash the Firmware

```bash
# Transfer firmware (Windows → Router)
scp -O -o HostKeyAlgorithms=+ssh-rsa firmware-mesh.bin root@192.168.1.1:/tmp/

# SSH in and flash
ssh -o HostKeyAlgorithms=+ssh-rsa root@192.168.1.1
sysupgrade -n /tmp/firmware-mesh.bin
# Wait 2–3 minutes for full reboot
```

### Phase 2 — Configure Mesh + Assign a Unique IP

After reboot, clear the stale SSH host key on Windows:

```cmd
ssh-keygen -R 192.168.1.1
```

Reconnect and apply the mesh + IP configuration:

```bash
ssh -o HostKeyAlgorithms=+ssh-rsa root@192.168.1.1

# Configure 802.11s mesh
uci set wireless.radio0.disabled='0'
uci set wireless.default_radio0.mode='mesh'
uci set wireless.default_radio0.mesh_id='Yanis_Mesh'
uci set wireless.default_radio0.network='lan'
uci set wireless.default_radio0.mesh_fwding='1'

#  CRITICAL: Avoid IP conflict with Node 1
uci set network.lan.ipaddr='192.168.1.2'
uci commit

/etc/init.d/network restart
# SSH session will freeze here — that's expected (IP changed)
```

### Phase 3 — Validate the Mesh Link

1. Power on **Node 1** (192.168.1.1)
2. Keep your PC wired to **Node 2** (192.168.1.2)
3. Wait ~60 seconds for 802.11s to negotiate the radio link

```cmd
ping 192.168.1.1
```

**Success looks like:**
```
Pinging 192.168.1.1 with 32 bytes of data:
Reply from 192.168.1.1: bytes=32 time=2ms TTL=64
Reply from 192.168.1.1: bytes=32 time=3ms TTL=64
```

A response confirms **Layer 2 mesh connectivity** — packets are crossing the radio link invisibly via 802.11s.

---

##  Feasibility: OpenWrt on PC

A natural evolution of this project is adding a **Mesh Portal Point (MPP)** — a PC running OpenWrt x86 that bridges the mesh to wired infrastructure and hosts IoT services.

### Why a PC Eliminates All Our Constraints

| Constraint | TL-WA830RE v2 | PC (OpenWrt x86) |
|---|---|---|
| Flash / Storage | 4 MB — critical | ≥ 32 GB — zero constraint |
| RAM | 32 MB | 512 MB – 16 GB |
| Install `wpad-mesh` |  Impossible via opkg → Image Builder required |  `opkg install` (< 1 min) |
| MQTT Broker |  No space |  Installable freely |
| Sensor Database |  No space |  SQLite/InfluxDB |
| Power draw | ~3–5 W | ~15–65 W |
| Role in 802.11s | Mesh Point / Mesh AP | **Mesh Portal Point** |

### Quick Install on PC

```bash
# On OpenWrt x86 — trivially replace wpad
opkg update
opkg remove wpad-basic-wolfssl
opkg install wpad-mesh-openssl

# Same UCI commands as the TP-Link nodes
uci set wireless.default_radio0.mode='mesh'
uci set wireless.default_radio0.mesh_id='Yanis_Mesh'
uci set wireless.default_radio0.mesh_fwding='1'
uci commit && /etc/init.d/network restart
```

  **Wi-Fi card requirement:** Only chipsets supported by `ath9k` (Atheros), `ath10k-ct` (Qualcomm), or `mt76` (MediaTek) support Mesh Point mode. Intel integrated Wi-Fi (iwlwifi) does **not** support 802.11s mesh without custom kernel compilation.

### Interoperability

802.11s is an **open standard** — a PC node with an Atheros/MediaTek card and the TP-Link nodes (Atheros ar71xx chipset) are fully interoperable as long as `mesh_id` and radio channel parameters match.

---

##  Results & Validation

| Milestone | Status |
|---|---|
| Custom firmware compiled under WSL/Ubuntu | success |
| Image fits within 4 MB Flash | success |
| Firmware flashed via `sysupgrade -n` |success  |
| `iw list` confirms Mesh Point capability | success |
| Node 2 configured with unique IP (192.168.1.2) | success |
| Ping across mesh link successful | success |
| Layer 2 decentralized communication verified | success |



---
 
##  Scripts Reference
 
All scripts live in the `scripts/` folder. Here is what each one does and when to run it.
 
### Execution Order
 
```
Step 1 (WSL/Ubuntu)   →   build-firmware.sh    →  produces firmware-mesh.bin
Step 2 (Windows CMD)  →   flash-node.bat        →  transfers + flashes it onto the router
Step 3 (Router SSH)   →   node2-setup.sh        →  configures 802.11s mesh on Node 2
Step 4 (Router SSH)   →   verify-mesh.sh        →  confirms the mesh link is alive
```
 
---
 
### `build-firmware.sh` — WSL / Ubuntu
 
Downloads the OpenWrt Image Builder for `ar71xx/tiny`, bypasses the broken Python 2 / GCC prerequisite checker, strips every non-essential package, and outputs `firmware-mesh.bin`.
 
```bash
chmod +x scripts/build-firmware.sh
./scripts/build-firmware.sh
```
 
Key flags used internally:
 
```bash
make image \
  PROFILE="tl-wa830re-v2" \
  PACKAGES="wpad-mesh -wpad-mini -ppp -kmod-pppoe \
            -firewall -iptables -ip6tables \
            -odhcpd-ipv6only -dnsmasq -opkg" \
  BUILD_LOG=1
```
 

 
---
 
### `flash-node.bat` — Windows CMD
 
Automates the two-step flash process: SCP transfer (using the `-O` legacy flag required by Dropbear) followed by opening the SSH session.
 
```cmd
scripts\flash-node.bat
```
 
Inside the SSH session that opens, run:
```bash
sysupgrade -n /tmp/firmware-mesh.bin
```
 
 The router will reboot automatically. Wait 2–3 minutes.
 
---
 
### `node2-setup.sh` — Router SSH (after flash)
 
Applies the full 802.11s mesh configuration and assigns the unique IP `192.168.1.2` to prevent conflict with Node 1. Run it on the router after the firmware reboot.
 
```bash
# From Windows, reconnect after flash
ssh -o HostKeyAlgorithms=+ssh-rsa root@192.168.1.1
 
# Then on the router
sh node2-setup.sh
```
 
   Your SSH session will freeze when the script restarts the network — that's expected. The router's IP just moved to `192.168.1.2`. Reconnect with `ssh root@192.168.1.2`.
 
---
 
### `verify-mesh.sh` — Router SSH (validation)
 
Runs 6 automated checks after setup is complete:
 
| Check | Command used | What it confirms |
|---|---|---|
| 1 | `iw list` | Driver reports Mesh Point capability |
| 2 | `iw dev` | Mesh interface is UP |
| 3 | `iw dev wlan0 mpath dump` | Peer table shows discovered neighbors |
| 4 | `iw dev wlan0 station dump` | Signal strength and bitrate to peers |
| 5 | `df -h /overlay` | Flash usage health |
| 6 | `uci show` | mesh_id, mode, forwarding, and IP confirmed |
 
```bash
ssh -o HostKeyAlgorithms=+ssh-rsa root@192.168.1.2
sh verify-mesh.sh
```
 
**Healthy output from Check 3 looks like:**
 
```
DEST ADDR          NEXT HOP           IFACE  SN  METRIC  QLEN  EXP  DTI  FLAGS
aa:bb:cc:dd:ee:ff  aa:bb:cc:dd:ee:ff  wlan0  1   0       0     ...  ...  0x...
```
 
A populated peer table means the 802.11s radio negotiation succeeded and your mesh is live.
 
---

##  References

1. OpenWrt Project — [x86 target downloads](https://openwrt.org/downloads)
2. OpenWrt Project — [OpenWrt on x86 hardware](https://openwrt.org/docs/guide-user/installation/openwrt_x86)
3. OpenWrt Project — [IEEE 802.11s Mesh Networking](https://openwrt.org/docs/guide-user/network/wifi/mesh/80211s)
4. IEEE Std 802.11s-2011 — *Amendment 10: Mesh Networking*, IEEE, 2011
5. OpenWISP — [How to Set Up a Wireless Mesh Network (802.11s)](https://openwisp.io/docs/dev/tutorials/mesh.html)
6. B. Ahlgren et al. — *A Survey of Information-Centric Networking*, IEEE Commun. Mag., vol. 50, no. 7, 2012

---

<div align="center">

**Bouazzi Yanis · Ranem Younes · Aoues Nassim · Yemi Mounir**

*4th Year Engineering — Advanced Telecommunications · 2025–2026*

---

*"Advanced software optimization can overcome hardware obsolescence."*

</div>
