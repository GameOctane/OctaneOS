# OctaneOS build overrides
# host-ruby 3.3.5 gc.c triggers -Wformat= errors on GCC 12+ due to PRIdSIZE
# expanding incorrectly. Pass --disable-werror so the build doesn't abort.
HOST_RUBY_CONF_OPTS += --disable-werror
