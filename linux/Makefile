export OUT=$(PWD)/out
export BOOT=$(OUT)/boot.img
export ARCH=arm64
export CROSS_COMPILE=/usr/bin/aarch64-linux-gnu-
export BOOT_UUID=95E46EA5

clean:
	cd linux; \
	sudo make mrproper

kernel: buildkernel postbuildkernel

buildkernel:
	cd linux; \
	sudo \rm -rf tmp; mkdir tmp; mkdir -p tmp/lib; \
	sudo make mrproper; \
	make defconfig; \
	make all -j8; \
	sudo make ARCH=arm64 INSTALL_MOD_PATH=./tmp modules_install; \
	sudo make ARCH=arm64 INSTALL_DTBS_PATH=./tmp/boot/dtb dtbs_install; \
	sudo make ARCH=arm64 INSTALL_PATH=./tmp/boot install

postbuildkernel:
	cd linux; \
	\rm -f $(BOOT); \
	mkfs.vfat -n "boot" -i ${BOOT_UUID} -S 512 -C ${BOOT} 512000; \
	mcopy -i ${BOOT} -s ../firmware/fixup4.dat ::; \
	mcopy -i ${BOOT} -s ../firmware/start4.elf ::; \
	mcopy -i ${BOOT} -s ../firmware/bootcode.bin ::; \
	mcopy -i ${BOOT} -s ../firmware/cmdline.txt ::; \
	mcopy -i ${BOOT} -s ../firmware/config.txt ::; \
	mcopy -i ${BOOT} -s ./arch/arm64/boot/Image ::/kernel_2712.img; \
	mcopy -i ${BOOT} -s ./arch/arm64/boot/dts/broadcom/bcm2712-rpi-5-b.dtb ::; \
