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
	@# Add crypto_akcipher_sync_encrypt compat inline. This symbol was removed
	@# from 5.15 upstream; out-of-tree modules (xone) still reference it.
	@# Inject a static inline before the final #endif in akcipher.h.
	grep -qF 'crypto_akcipher_sync_encrypt' $(@D)/include/crypto/akcipher.h || \
		$(SED) 's/^#endif$$/\n\/* OctaneOS compat: crypto_akcipher_sync_encrypt removed from 5.15 *\/\nstruct __akcipher_sync_cb { struct completion c; int err; };\nstatic inline void __akcipher_sync_done(struct crypto_async_request *r, int e) { struct __akcipher_sync_cb *cb = r->data; if (e != -EINPROGRESS) { cb->err = e; complete(\&cb->c); } }\nstatic inline int crypto_akcipher_sync_encrypt(struct crypto_akcipher *t, const void *s, unsigned int sl, void *d, unsigned int dl) { struct __akcipher_sync_cb cb; struct akcipher_request *req; struct scatterlist si, so; int e; req = akcipher_request_alloc(t, GFP_KERNEL); if (!req) return -ENOMEM; init_completion(\&cb.c); sg_init_one(\&si, s, sl); sg_init_one(\&so, d, dl); akcipher_request_set_crypt(req, \&si, \&so, sl, dl); akcipher_request_set_callback(req, CRYPTO_TFM_REQ_MAY_BACKLOG, __akcipher_sync_done, \&cb); e = crypto_akcipher_encrypt(req); if (e == -EINPROGRESS || e == -EBUSY) { wait_for_completion(\&cb.c); e = cb.err; } akcipher_request_free(req); return e; }\n\n#endif/' \
		$(@D)/include/crypto/akcipher.h
endef
LINUX_POST_PATCH_HOOKS += LINUX_BATOCERA_FETCH_ALLWINNER_BSP
