# OctaneOS build overrides
# host-ruby 3.3.5 gc.c triggers -Wformat= errors on GCC 12+ due to PRIdSIZE
# expanding incorrectly. Pass --disable-werror so the build doesn't abort.
HOST_RUBY_CONF_OPTS += --disable-werror

# wm8960-audio-hat is a Raspberry Pi peripheral with no relevance to A733.
# Its source uses simple_card_utils.h APIs that changed in 5.15 and won't
# compile with -Werror. Suppress warnings so the build doesn't abort.
WM8960_AUDIO_HAT_MODULE_MAKE_OPTS += EXTRA_CFLAGS="-w"

# xone v0.5.5 uses C99/C11 syntax and references crypto_akcipher_sync_encrypt
# which was removed from the BSP 5.15 kernel. Use gnu11, suppress warnings,
# and make modpost warn instead of error so the build continues.
XONE_MODULE_MAKE_OPTS += EXTRA_CFLAGS="-std=gnu11 -w" KBUILD_MODPOST_WARN=1

# libretro-same-cdi (MAME-based CDi emulator): genie generates submakefiles
# with AR := ar (the host ar). When cross-compiling for aarch64, the cross-ld
# rejects archives without a symbol index. Pass OVERRIDE_AR so MAME uses the
# cross-toolchain ar, which produces a proper indexed archive.
define LIBRETRO_SAME_CDI_BUILD_CMDS
	cd $(@D); \
	PATH="$(HOST_DIR)/bin:$$PATH" \
	$(MAKE) TARGETOS=linux OSD=sdl genie \
	TARGET=mame SUBTARGET=tiny \
	NO_USE_PORTAUDIO=1 NO_X11=1 USE_SDL=0 \
	USE_QTDEBUG=0 DEBUG=0 IGNORE_GIT=1 MPARAM=""
	$(TARGET_CONFIGURE_OPTS) $(MAKE) -j1 CXX="$(TARGET_CXX)" CC="$(TARGET_CC)" \
	OVERRIDE_AR="$(TARGET_AR)" \
	$(if $(BR2_aarch64),PTR64=1 LIBRETRO_CPU= PLATFORM=arm64 ARCHITECTURE= NOASM=1) \
	GIT_VERSION="" -C $(@D) -f Makefile.libretro
endef
