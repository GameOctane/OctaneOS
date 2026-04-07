# Radxa allwinner-bsp is a companion repo to the allwinner-aiot kernel.
# It provides the bsp/ directory that the kernel Makefile and Kconfig reference.
# Clone it into the kernel build tree after extraction.

define LINUX_BATOCERA_FETCH_ALLWINNER_BSP
	if [ ! -f $(@D)/bsp/Makefile ]; then \
		rm -rf $(@D)/bsp; \
		echo ">>> Fetching Radxa allwinner-bsp into kernel bsp/ directory..."; \
		git clone --depth=1 -b cubie-aiot-v1.4.8 \
			https://github.com/radxa/allwinner-bsp \
			$(@D)/bsp; \
	fi
	@# modules/nand and modules/gpu are standalone out-of-tree modules that
	@# require KERNEL_SRC_DIR set externally — they cannot be built in-tree.
	@# Remove them from the bsp/Makefile to allow the kernel build to succeed.
	$(SED) '/^obj-y += modules\//d' $(@D)/bsp/Makefile
	@# Copy all BSP dt-bindings headers into the kernel's include/dt-bindings
	@# tree. The DTS/DTSI files reference BSP-specific headers (sunxi-clk.h,
	@# sun60iw2-*.h, etc.) that are not shipped with the kernel source.
	cp -rf $(@D)/bsp/include/dt-bindings/. $(@D)/include/dt-bindings/
	@# Copy the Cubie A7S DTS + sun60iw2p1 SoC DTSI files from our board
	@# directory into the kernel DTS tree and register them.
	cp -f $(BR2_EXTERNAL_BATOCERA_PATH)/board/batocera/allwinner/a733/dts/sun60iw2p1.dtsi \
		$(@D)/arch/arm64/boot/dts/allwinner/
	cp -f $(BR2_EXTERNAL_BATOCERA_PATH)/board/batocera/allwinner/a733/dts/sun60iw2p1-cpu-vf.dtsi \
		$(@D)/arch/arm64/boot/dts/allwinner/
	cp -f $(BR2_EXTERNAL_BATOCERA_PATH)/board/batocera/allwinner/a733/dts/sun60i-a733-cubie-a7s.dts \
		$(@D)/arch/arm64/boot/dts/allwinner/
	grep -qF 'sun60i-a733-cubie-a7s.dtb' $(@D)/arch/arm64/boot/dts/allwinner/Makefile || \
		echo 'dtb-$(CONFIG_ARCH_SUNXI) += sun60i-a733-cubie-a7s.dtb' \
		>> $(@D)/arch/arm64/boot/dts/allwinner/Makefile
endef
LINUX_POST_PATCH_HOOKS += LINUX_BATOCERA_FETCH_ALLWINNER_BSP
