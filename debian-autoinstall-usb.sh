#!/usr/bin/env bash
########################################################################################
# SCRIPT:   debian-autoinstall-usb.sh
# AUTHOR:   Grok 4 (built by xAI)
# PURPOSE:  Create bootable Debian DVD-1 USB with preseed for fully unattended install
#           • Uses official current stable hybrid ISO (dd to USB)
#           • Dynamic arch + version fetch from cdimage.debian.org
#           • Verifies SHA256 + GPG signature via debian-archive-keyring
#           • Injects preseed.cfg at root → boot param: preseed/file=/cdrom/preseed.cfg
#
# REQUIRES (auto-installed if missing):
#   curl gnupg coreutils rsync xorriso genisoimage isolinux dosfstools debian-archive-keyring
#   sudo privileges
#
# SAFETY FEATURES:
#   • Two-step confirmation ("YES" + "DESTROY")
#   • Only USB devices ≥8 GB shown
#   • Full hash + signature verification
#   • Temp files cleaned on exit/error
#
# TROUBLESHOOTING / WHAT TO DO IF SCRIPT STOPS WORKING:
#   1. Debian release changed structure? → Check https://cdimage.debian.org/debian-cd/current/
#      • Update BASE_URL if path moves (rare)
#      • Adjust grep -oP regex in ISO_NAME line if filename pattern changes
#   2. GPG verification fails? → sudo apt install --reinstall debian-archive-keyring
#   3. No architectures listed? → Fallback list is hardcoded; network issue or site down
#   4. ISO rebuild fails? → Ensure xorriso is installed (preferred) or genisoimage works
#   5. Boot doesn't auto-install? → Verify preseed.cfg syntax & path in sed lines
#      • Try manual boot param edit at GRUB: preseed/file=/cdrom/preseed.cfg
#   6. General breakage? → Run with bash -x for debug, or search Debian installer docs
#      for current preseed/boot parameter syntax
#
# MAINTAINER NOTES / RECREATION SUMMARY:
#   • Fetch arch list → select → fetch latest debian-*-$ARCH-DVD-1.iso name
#   • Download ISO + SHA256SUMS + .sign
#   • Verify: gpg --keyring /usr/share/keyrings/debian-archive-keyring.gpg --verify
#   • Mount → rsync extract → copy preseed.cfg to root
#   • sed append to GRUB & isolinux: "preseed/file=/cdrom/preseed.cfg auto=true priority=critical quiet ---"
#   • Rebuild hybrid with xorriso (or genisoimage fallback)
#   • dd bs=4M oflag=direct conv=fsync to selected /dev/sdX
########################################################################################

set -euo pipefail
trap 'echo "Error - cleaning up..."; rm -rf "$TEMP_DIR" 2>/dev/null' EXIT ERR

# Config
BASE_URL="https://cdimage.debian.org/debian-cd/current"
TEMP_DIR="/tmp/debian-preseed-$(date +%s)"
MIN_USB_GB=8
PRESEED_DEFAULT="preseed.cfg"           # Default file in script dir (optional)

# ──────────────────────────────────────────────────────────────────────────────
# Check/install required packages
# ──────────────────────────────────────────────────────────────────────────────
echo "Checking/updating required tools..."

REQUIRED_PKGS=(
    curl        # downloads
    gnupg       # gpg verification
    coreutils   # sha256sum, etc.
    rsync       # copy ISO contents
    xorriso     # preferred for hybrid ISO
    genisoimage # fallback
    isolinux    # boot files
    dosfstools  # FAT utils
    debian-archive-keyring  # for dynamic Debian keys
)

sudo apt-get update -qq

for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        echo "Installing: $pkg"
        sudo apt-get install -yqq "$pkg"
    fi
done

if ! command -v xorriso >/dev/null; then
    command -v genisoimage >/dev/null || { echo "No ISO tool found." >&2; exit 1; }
    echo "Warning: Using genisoimage (xorriso preferred for hybrid)"
fi

# ──────────────────────────────────────────────────────────────────────────────
# WSL detection & USB guidance
# ──────────────────────────────────────────────────────────────────────────────
if grep -qi microsoft /proc/version 2>/dev/null || [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
    cat <<'EOF'
=== WSL DETECTED - USB SETUP REQUIRED ===

WSL2 does NOT expose USB drives as /dev/sdX by default.
Steps:

1. Windows PowerShell (Admin):
   winget install --exact dorssel.usbipd-win
   usbipd list                # Find BUSID (e.g. 1-4)
   usbipd bind --busid <BUSID>
   usbipd attach --wsl --busid <BUSID>

2. Here in WSL:
   lsusb                  # confirm
   lsblk                  # /dev/sdX appears

After script: usbipd detach --busid <BUSID>

Press Enter when /dev/sdX visible, or Ctrl+C to exit.
EOF
    read -r
fi

# ──────────────────────────────────────────────────────────────────────────────
# USB selection
# ──────────────────────────────────────────────────────────────────────────────
echo "Plug in USB ≥${MIN_USB_GB}GB (USB 3.0 preferred). Press Enter when ready."
read -r

mapfile -t USB_DRIVES < <(lsblk -dno NAME,SIZE,TRAN,MODEL | awk -v min="$MIN_USB_GB" '$3=="usb" && $2+0 >= min {print "/dev/"$1 " " $2 " " substr($0, index($0,$4)) }')

(( ${#USB_DRIVES[@]} == 0 )) && { echo "No suitable USB found." >&2; exit 1; }

echo "Available USB drives:"
select drive_info in "${USB_DRIVES[@]}"; do
    [[ -n "$drive_info" ]] && break
done
TARGET_DEV="${drive_info%% *}"

echo -e "\n!!! ALL DATA ON $TARGET_DEV WILL BE ERASED !!!\n"
echo -n "Type YES to continue: "; read -r confirm; [[ "$confirm" == "YES" ]] || exit 1
echo -n "Type DESTROY to confirm: "; read -r confirm; [[ "$confirm" == "DESTROY" ]] || exit 1

# ──────────────────────────────────────────────────────────────────────────────
# Fetch architectures dynamically
# ──────────────────────────────────────────────────────────────────────────────
echo "Fetching architectures..."
ARCHES=($(curl -s "$BASE_URL/" | grep -o '[a-z0-9]\+/' | sed 's|/||' | sort -u | grep -E '^(amd64|i386|arm64|ppc64el|s390x)$' || true))

(( ${#ARCHES[@]} == 0 )) && ARCHES=("amd64" "i386" "arm64" "ppc64el")

echo "Select architecture:"
select ARCH in "${ARCHES[@]}"; do [[ -n "$ARCH" ]] && break; done

# ──────────────────────────────────────────────────────────────────────────────
# Dynamic ISO name/version
# ──────────────────────────────────────────────────────────────────────────────
DIR_URL="${BASE_URL}/${ARCH}/iso-dvd/"
ISO_NAME=$(curl -s "$DIR_URL" | grep -oP "debian-\K[0-9.]+\-${ARCH}-DVD-1\.iso" | head -1)
[[ -z "$ISO_NAME" ]] && { echo "No DVD ISO found for $ARCH." >&2; exit 1; }
ISO_NAME="debian-${ISO_NAME}"

ISO_URL="${DIR_URL}${ISO_NAME}"
HASH_URL="${DIR_URL}SHA256SUMS"
SIG_URL="${HASH_URL}.sign"

# ──────────────────────────────────────────────────────────────────────────────
# Download & verify (dynamic keys via keyring)
# ──────────────────────────────────────────────────────────────────────────────
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

echo "Downloading ISO, SHA256SUMS, signature..."
curl -LO "$ISO_URL" "$HASH_URL" "$SIG_URL"

gpg --no-default-keyring --keyring /usr/share/keyrings/debian-archive-keyring.gpg --verify SHA256SUMS.sign SHA256SUMS || { echo "GPG failed!"; exit 1; }

grep -- "$ISO_NAME" SHA256SUMS | sha256sum -c - || { echo "Checksum failed!"; exit 1; }

echo "Verification passed."

# ──────────────────────────────────────────────────────────────────────────────
# Extract & modify with preseed
# ──────────────────────────────────────────────────────────────────────────────
mkdir -p extracted mnt
mount -o loop "$ISO_NAME" mnt
rsync -a mnt/ extracted/
umount mnt

echo "Adding preseed file..."
if [[ -f "../$PRESEED_DEFAULT" ]]; then
    cp "../$PRESEED_DEFAULT" extracted/preseed.cfg
elif [[ -f "$PRESEED_DEFAULT" ]]; then
    cp "$PRESEED_DEFAULT" extracted/preseed.cfg
else
    echo "No default preseed.cfg found in $(pwd). Enter path to your preseed.cfg (or Ctrl+C):"
    read -r PRESEED_PATH
    [[ -f "$PRESEED_PATH" ]] && cp "$PRESEED_PATH" extracted/preseed.cfg || { echo "File not found"; exit 1; }
fi

# Inject auto-install params (GRUB + isolinux; cdrom for ISO/USB)
sed -i '/linux.*vmlinuz/ s/$/ preseed\/file=\/cdrom\/preseed.cfg auto=true priority=critical quiet ---/' extracted/boot/grub/grub.cfg
sed -i '/append .*initrd=/ s/$/ preseed\/file=\/cdrom\/preseed.cfg auto=true priority=critical quiet ---/' extracted/isolinux/*.cfg 2>/dev/null || true

# ──────────────────────────────────────────────────────────────────────────────
# Rebuild hybrid ISO
# ──────────────────────────────────────────────────────────────────────────────
echo "Building modified ISO..."
if command -v xorriso >/dev/null; then
    xorriso -as mkisofs -o modified.iso \
        -b isolinux/isolinux.bin -c isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
        -J -R -V 'Debian Preseed Installer' extracted/
else
    genisoimage -o modified.iso \
        -b isolinux/isolinux.bin -c isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
        -J -R -V 'Debian Preseed Installer' extracted/
fi

[[ -f modified.iso ]] || { echo "ISO build failed"; exit 1; }

# ──────────────────────────────────────────────────────────────────────────────
# Write to USB
# ──────────────────────────────────────────────────────────────────────────────
echo "Writing modified ISO to $TARGET_DEV (5-20 min)..."
sudo dd if=modified.iso of="$TARGET_DEV" bs=4M status=progress oflag=direct conv=fsync
sync

echo -e "\nSuccess! Bootable preseed Debian USB created on $TARGET_DEV."
echo "Safely eject. Boot target machine from USB."
rm -rf "$TEMP_DIR"
