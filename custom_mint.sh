#!/bin/bash

set -e  # Exit on any error
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run this script with sudo:"
  echo "  sudo bash $0"
  exit 1
fi

#full build
#ISO_URL="https://mirrors.edge.kernel.org/linuxmint/stable/21.3/linuxmint-21.3-cinnamon-64bit.iso"
#lightweight desktop
ISO_URL="https://mirrors.edge.kernel.org/linuxmint/stable/21.3/linuxmint-21.3-xfce-64bit.iso"
ISO_NAME="linuxmint-21.3-xfce-64bit.iso"
CUSTOM_ISO_NAME="linuxmint-cf30.iso"

# === Install Required Tools ===
echo "[*] Installing required packages..."
apt update
apt install -y xorriso squashfs-tools genisoimage isolinux

# === Setup Directories ===
echo "[*] Preparing working directories..."
mkdir -p ./mint-custom/{iso,edit,mount,extract}
cd ./mint-custom

# === Download and Mount ISO ===
echo "[*] Downloading original Linux Mint ISO..."
[ -f $ISO_NAME ] || wget $ISO_URL

MOUNT_DIR="mount"

# Check if already mounted
if findmnt -rno TARGET "$MOUNT_DIR" > /dev/null; then
    echo "[✓] ISO is already mounted at $MOUNT_DIR"
else
    echo "[*] Mounting ISO..."
    sudo mount -o loop "$ISO_NAME" "$MOUNT_DIR"
fi

# === Extract ISO Contents ===
echo "[*] Extracting ISO contents..."
rsync -a mount/ extract/
[ -d squashfs-root ] && sudo rm -rf squashfs-root
unsquashfs extract/casper/filesystem.squashfs
mv squashfs-root/* edit/

# === Prepare for CHROOT ===
echo "[*] Binding system directories for chroot..."
for d in dev run proc sys dev/pts; do
  sudo mount --bind /$d edit/$d
done

echo "[*] Entering chroot to customize..."
chroot edit /bin/bash <<'EOL'
export HOME=/root
export LC_ALL=C

apt update
DEBIAN_FRONTEND=noninteractive apt install -y gpsd gpsd-clients foxtrotgps viking ssh libdvd-pkg vlc regionset

exit
EOL

# === Post-Chroot File Copy ===
echo "[*] Copying additional setup scripts..."
cp setup-gpsd.sh edit/usr/local/bin/
cp region.sh edit/usr/local/bin/
chmod +x edit/usr/local/bin/region.sh edit/usr/local/bin/setup-gpsd.sh
cp setup-gpsd.service edit/etc/systemd/system/

# === Re-enter Chroot to Enable Service ===
echo "[*] Enabling setup-gpsd.service inside chroot..."
chroot edit /bin/bash <<'EOL'
systemctl enable setup-gpsd.service
apt clean
exit
EOL

# === Unmount System Directories ===
echo "[*] Unmounting system directories..."
for d in proc sys dev/pts dev run; do
  umount -l edit/$d || true
done
umount mount

# === Rebuild Filesystem ===
echo "[*] Rebuilding squashfs..."
mksquashfs edit extract/casper/filesystem.squashfs -noappend

# === Update Manifest ===
echo "[*] Updating manifest..."
chmod +w extract/casper/filesystem.manifest
chroot edit dpkg-query -W --showformat='${Package} ${Version}\n' > extract/casper/filesystem.manifest

# === Copy Boot Loader Binary ===
echo "[*] Copying boot loader binary..."
cp /usr/lib/ISOLINUX/isohdpfx.bin extract/isolinux/

# === Build New ISO ===
echo "[*] Creating new ISO image..."
cd extract
echo "[*] Current working directory: $(pwd)"
xorriso -as mkisofs \
  -r -J -l -V "LinuxMint_CF-30" \
  -o ../$CUSTOM_ISO_NAME \
  -isohybrid-mbr isolinux/isohdpfx.bin \
  -partition_offset 16 \
  -b isolinux/isolinux.bin \
  -c isolinux/boot.cat \
  -no-emul-boot -boot-load-size 4 -boot-info-table .

cd ..
echo "Cleaning up directory..."
#rm -rf extract/* edit/*
#rm -rf squashfs-root

echo "[✓] Custom ISO created: $CUSTOM_ISO_NAME"
echo "[✓] You can now write it to USB using:"
echo "    sudo dd if=$CUSTOM_ISO_NAME of=/dev/sdX bs=4M status=progress oflag=sync"
echo "    OR use Balena Etcher"

