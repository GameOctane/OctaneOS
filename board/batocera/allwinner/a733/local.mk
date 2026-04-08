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
