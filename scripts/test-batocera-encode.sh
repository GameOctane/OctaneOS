#!/bin/bash
# Test the OctaneOS batocera-encode override (the key that hides the stored device password) against a fake /sys/class/net, no board needed.
# The bug it guards against, found on the board: eth0 gets a RANDOM MAC at every boot, so the stock key changed and the password was lost.
# Usage: scripts/test-batocera-encode.sh        exit status 0 = all tests passed
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENC="${REPO_ROOT}/board/batocera/allwinner/a733/fsoverlay/usr/bin/batocera-encode"
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT
PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; fi; }
export OCTANE_CPUINFO="${T}/cpuinfo"; : > "${OCTANE_CPUINFO}"
export OCTANE_SYS_NET="${T}/net"
# iface <name> <mac> <addr_assign_type> [usb]: add a fake interface (type 0 = permanent, 1 = random)
iface() { mkdir -p "${T}/net/$1"; printf '%s\n' "$2" > "${T}/net/$1/address"; printf '%s\n' "$3" > "${T}/net/$1/addr_assign_type"
  if [ "${4:-}" = usb ]; then mkdir -p "${T}/dev/usb/$1"; ln -sfn "${T}/dev/usb/$1" "${T}/net/$1/device"; else mkdir -p "${T}/dev/soc/$1"; ln -sfn "${T}/dev/soc/$1" "${T}/net/$1/device"; fi; }
reset() { rm -rf "${T}/net" "${T}/dev"; mkdir -p "${T}/net/lo"; : > "${OCTANE_CPUINFO}"; }
enc() { sh "${ENC}" encode "$1" 2>/dev/null; }
dec() { sh "${ENC}" decode "$1"; }

echo "== a board like the A7S: random ethernet MAC at every boot, permanent wlan0, no CPU serial"
reset; iface eth0 8a:12:4e:de:5f:d1 1; iface wlan0 9c:04:b6:9d:4a:9b 0
S="$(enc 'my-test-pass')"
check "the stored text is marked enc:" '[[ "${S}" == enc:* ]]'
check "it decodes in the same boot" '[ "$(dec "${S}")" = "my-test-pass" ]'
iface eth0 02:aa:bb:cc:dd:ee 1      # next boot: a different random MAC
check "it still decodes after the random MAC changed (the bug)" '[ "$(dec "${S}")" = "my-test-pass" ]'
iface eth0 6e:11:22:33:44:55 1
check "...and after another reboot" '[ "$(dec "${S}")" = "my-test-pass" ]'

echo "== plugging in or removing a USB network adapter"
reset; iface eth0 8a:12:4e:de:5f:d1 1; iface wlan0 9c:04:b6:9d:4a:9b 0
S="$(enc 'usb-case-pass')"
iface eth1 00:e0:4c:11:22:33 0 usb
check "a USB adapter with a permanent MAC appears: still decodes" '[ "$(dec "${S}")" = "usb-case-pass" ]'
reset; iface eth0 8a:12:4e:de:5f:d1 1; iface wlan0 9c:04:b6:9d:4a:9b 0; iface eth1 00:e0:4c:11:22:33 0 usb
S="$(enc 'usb-first-pass')"
rm -rf "${T}/net/eth1"
check "stored while the adapter was there, adapter removed: still decodes" '[ "$(dec "${S}")" = "usb-first-pass" ]'

echo "== stock Batocera compatibility (permanent ethernet MAC, with a CPU serial)"
reset; iface eth0 aa:bb:cc:dd:ee:01 0; iface wlan0 9c:04:b6:9d:4a:9b 0
printf 'Processor\t: x\nSerial\t\t: 10000000deadbeef\n' > "${OCTANE_CPUINFO}"
STOCK="enc:$(echo 'stock-pass' | openssl enc -aes-128-cbc -a -salt -pass pass:"10000000deadbeefaa:bb:cc:dd:ee:01")"
check "a password stored by stock Batocera decodes" '[ "$(dec "${STOCK}")" = "stock-pass" ]'
S="$(enc 'new-pass')"
check "...and ours uses the same key (stock could read it)" '[ "$(echo "${S#enc:}" | openssl enc -aes-128-cbc -a -d -salt -pass pass:"10000000deadbeefaa:bb:cc:dd:ee:01" 2>/dev/null)" = "new-pass" ]'

echo "== failures are clean"
reset; iface eth0 8a:12:4e:de:5f:d1 1; iface wlan0 9c:04:b6:9d:4a:9b 0
S="$(enc 'lost-pass')"
reset; iface wlan0 9c:04:b6:ff:ff:ff 0
dec "${S}" >/dev/null 2>&1; RC=$?
check "a different permanent MAC cannot decode and exits non-zero" '[ "${RC}" -ne 0 ]'
reset; iface eth0 8a:12:4e:de:5f:d1 1
S="$(enc 'x')"; iface eth0 02:00:00:00:00:02 1; dec "${S}" >/dev/null 2>&1; RC=$?
check "a board with only random MACs fails visibly (documented limit)" '[ "${RC}" -ne 0 ]'
check "text without enc: is passed through" '[ "$(dec "plain")" = "plain" ]'

echo; echo "${PASS} passed, ${FAIL} failed"; [ "${FAIL}" -eq 0 ]
