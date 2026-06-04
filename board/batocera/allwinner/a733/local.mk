# OctaneOS build overrides

# =============================================================================
# Radxa 6.6 kernel — pre-baked source tree (kernel + allwinner-bsp merged)
#
# Run scripts/setup-kernel-66.sh once to populate linux/kernel-66/:
#   1. Clones radxa/kernel (allwinner-aiot-linux-6.6)
#   2. Clones radxa/allwinner-bsp (cubie-aiot-v1.4.8) into bsp/
#   3. Copies A733 DTSI files from bsp/configs/linux-6.6/ into the DTS tree
#   4. Copies dt-bindings headers from bsp/include/ into include/
#   5. Applies OctaneOS patches (board DTS, cpufreq A733 match)
#
# When LINUX_OVERRIDE_SRCDIR is set, Buildroot skips download/patch and builds
# the kernel directly from this directory.  Patches in linux_patches_66/ are
# applied by setup-kernel-66.sh (Buildroot does not apply them in override mode).
# =============================================================================
LINUX_OVERRIDE_SRCDIR = $(BR2_EXTERNAL)/../linux/kernel-66

# GCC 15 defaults to -std=gnu23 (C23). Many host packages use gnulib macros
# (e.g. _GL_ATTRIBUTE_NODISCARD) that break under C23. Force C11/C++11 for
# all host package compilations. local.mk is included after package/Makefile.in
# sets HOST_CFLAGS ?= -O2, so += appends without losing the base flags.
HOST_CFLAGS += -std=gnu11 -D_GL_ATTRIBUTE_NODISCARD= -Wno-incompatible-pointer-types
HOST_CXXFLAGS += -std=gnu++11 -D_GL_ATTRIBUTE_NODISCARD=

# CMake 4.0 dropped compatibility with cmake_minimum_required < 3.5.
# BR2_CMAKE uses ?= so we can override it here. Point it to a thin wrapper
# that adds -DCMAKE_POLICY_VERSION_MINIMUM=3.5 to every cmake invocation,
# fixing all affected packages (hiredis, etc.) globally.
BR2_CMAKE = $(BR2_EXTERNAL)/../scripts/host-cmake-compat
# host-heimdal uses crypt() which glibc 2.28+ moved to libxcrypt (-lcrypt).
# AC_CHECK_FUNCS(crypt) detects the function but does NOT add -lcrypt to LIBS,
# so libkrb5.so ends up with an unresolved crypt symbol. Override LIBS on the
# make command line to force the linker to include libcrypt.
HOST_HEIMDAL_MAKE_OPTS += LIBS="-pthread -lpthread -lcrypt"

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
