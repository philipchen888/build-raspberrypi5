#!/bin/bash -e

# Directory contains the target rootfs
TARGET_ROOTFS_DIR="binary"

if [ -e $TARGET_ROOTFS_DIR ]; then
	sudo rm -rf $TARGET_ROOTFS_DIR
fi

if [ "$ARCH" == "armhf" ]; then
	ARCH='armhf'
elif [ "$ARCH" == "arm64" ]; then
	ARCH='arm64'
else
    echo -e "\033[36m please input is: armhf or arm64...... \033[0m"
fi

if [ ! $VERSION ]; then
	VERSION="release"
fi

if [ ! -e live-image-$ARCH.tar.tar.gz ]; then
	echo "\033[36m Run sudo lb build first \033[0m"
fi

finish() {
	sudo umount -lf $TARGET_ROOTFS_DIR/proc || true
	sudo umount -lf $TARGET_ROOTFS_DIR/sys || true
	sudo umount -lf $TARGET_ROOTFS_DIR/dev/pts || true
	sudo umount -lf $TARGET_ROOTFS_DIR/dev || true
	exit -1
}
trap finish ERR

echo -e "\033[36m Extract image \033[0m"
sudo tar -xpf live-image-$ARCH.tar.tar.gz

sudo cp -rf ../linux/linux/tmp/lib/modules $TARGET_ROOTFS_DIR/lib

# packages folder
sudo mkdir -p $TARGET_ROOTFS_DIR/packages
sudo cp -rf ../packages/$ARCH/* $TARGET_ROOTFS_DIR/packages
sudo cp -rf ../linux/linux/tmp/boot/* $TARGET_ROOTFS_DIR/boot
sudo cp ../linux/patches/40_custom_uuid $TARGET_ROOTFS_DIR/boot
sudo cp ../linux/patches/debian/fstab $TARGET_ROOTFS_DIR/boot

# overlay folder
sudo cp -rf ../overlay/* $TARGET_ROOTFS_DIR/

echo -e "\033[36m Change root.....................\033[0m"
if [ "$ARCH" == "armhf" ]; then
	sudo cp /usr/bin/qemu-arm-static $TARGET_ROOTFS_DIR/usr/bin/
elif [ "$ARCH" == "arm64"  ]; then
	sudo cp /usr/bin/qemu-aarch64-static $TARGET_ROOTFS_DIR/usr/bin/
fi
sudo mount -o bind /proc $TARGET_ROOTFS_DIR/proc
sudo mount -o bind /sys $TARGET_ROOTFS_DIR/sys
sudo mount -o bind /dev $TARGET_ROOTFS_DIR/dev
sudo mount -o bind /dev/pts $TARGET_ROOTFS_DIR/dev/pts

cat << EOF | sudo chroot $TARGET_ROOTFS_DIR

rm -rf /etc/resolv.conf
echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf
resolvconf -u
apt-get update
apt-get upgrade -y
apt-get install -y build-essential git wget grub-efi-arm64 e2fsprogs zstd

# Install and configure GRUB
cp /boot/fstab /etc/fstab
rm -rf /boot/fstab
mkdir -p /boot/efi
grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
update-grub

cp /boot/40_custom_uuid /etc/grub.d/
chmod +x /etc/grub.d/40_custom_uuid
rm -rf /boot/40_custom_uuid

# Fix mouse lagging issue
cat << MOUSE_EOF >> /etc/environment
MUTTER_DEBUG_ENABLE_ATOMIC_KMS=0
MUTTER_DEBUG_FORCE_KMS_MODE=simple
CLUTTER_PAINT=disable-dynamic-max-render-time
MOUSE_EOF

# Migrate extlinux.conf to GRUB
rm -rf /boot/extlinux
cat << GRUB_EOF > /etc/default/grub
GRUB_DEFAULT="Boot from UUID"
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX=""
GRUB_EOF

update-grub

chmod o+x /usr/lib/dbus-1.0/dbus-daemon-launch-helper
chmod +x /etc/rc.local

dpkg -i /packages/rpiwifi/firmware-brcm80211_20240909-2_all.deb
cp /packages/rpiwifi/brcmfmac43455-sdio.txt /lib/firmware/brcm/
apt-get install -f -y

systemctl enable rc-local
systemctl enable resize-helper
update-initramfs -c -k 6.8.0-rc4

#---------------Clean--------------
rm -rf /var/lib/apt/lists/*
sync
EOF

sudo umount -lf $TARGET_ROOTFS_DIR/proc || true
sudo umount -lf $TARGET_ROOTFS_DIR/sys || true
sudo umount -lf $TARGET_ROOTFS_DIR/dev/pts || true
sudo umount -lf $TARGET_ROOTFS_DIR/dev || true
sync