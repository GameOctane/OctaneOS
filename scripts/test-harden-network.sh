#!/bin/bash
# Test scripts/harden-network-defaults.py.
#
# Uses small fixtures that contain the exact upstream text each patch looks for, then also RUNS the
# patched shell snippets (the NFS guard, the Syncthing address choice) against stand-ins, so a typo in
# the inserted shell code is caught here and not on a device.
# Usage: scripts/test-harden-network.sh        exit status 0 = all tests passed
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARDEN="${REPO_ROOT}/scripts/harden-network-defaults.py"
T="$(mktemp -d)"
[ -n "${T}" ] && [ -d "${T}" ] || { echo "cannot create a temporary folder" >&2; exit 2; }
trap 'rm -rf "${T:?}"' EXIT

PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; fi; }

# a target folder with the upstream text each patch expects
make_target() {
    local d="$1"
    rm -rf "${d:?}"; mkdir -p "${d}/etc/samba" "${d}/etc/init.d" "${d}/usr/share/batocera/services" "${d}/usr/share/batocera/datainit/system"
    printf '[global]\n   workgroup = WORKGROUP\n\n[share]\ncomment = batocera.linux user data\npath = /userdata\nwriteable = yes\nguest ok = yes\nforce user = root\nveto files = /._*/.DS_Store/\ndelete veto files = yes\n' > "${d}/etc/samba/smb.conf"
    printf '#!/bin/sh\nstart() {\n\t# Start daemons.\n\tprintf "Starting NFS statd: "\n\trpc.statd\n\techo started > "${NFS_MARKER:-/dev/null}"\n}\nstop() {\n\ttrue\n}\ncase "$1" in\n\tstart) start;;\nesac\n' > "${d}/etc/init.d/S60nfs"
    printf '#!/bin/sh\nstart() {\n\tSYNCTHING_SECURITY="$(/usr/bin/batocera-settings-get system.security.enabled)"\n\tif [ "$SYNCTHING_SECURITY"  != "1" ] || [ -z $SYNCTHING_SECURITY ]\n\tthen\n\t\tSYNCTHING_GUI="http://0.0.0.0:8384"\n\telse\n\t\tSYNCTHING_GUI="http://127.0.0.1:8384"\n\tfi\n\techo "GUI=$SYNCTHING_GUI"\n}\nstart\n' > "${d}/usr/share/batocera/services/syncthing"
    printf '## Wifi\n#wifi.country=FR\nwifi.enabled=0\n#wifi.ssid=new ssid\n' > "${d}/usr/share/batocera/datainit/system/batocera.conf"
}

echo "== patching"
make_target "${T}/t1"
OUT=$("${HARDEN}" "${T}/t1" 2>&1); RC=$?
check "first run patches all four things, exit 0" '[ "${RC}" = 0 ] && [ "$(echo "${OUT}" | grep -c "patched:")" = 4 ]'
OUT2=$("${HARDEN}" "${T}/t1" 2>&1); RC=$?
check "second run changes nothing and exits 0" '[ "${RC}" = 0 ] && [ "$(echo "${OUT2}" | grep -c "already patched")" = 4 ]'
check "the share veto list keeps the old patterns and adds ours" 'grep -qx "veto files = /._\*/.DS_Store/system/retroachievements.conf/.default-retroachievements.conf/" ${T}/t1/etc/samba/smb.conf'
check "the veto list appears exactly once" '[ "$(grep -c "^veto files" ${T}/t1/etc/samba/smb.conf)" = 1 ]'
check "Wi-Fi is on, the country is NOT set" 'grep -qx "wifi.enabled=1" ${T}/t1/usr/share/batocera/datainit/system/batocera.conf && ! grep -q "^wifi.country" ${T}/t1/usr/share/batocera/datainit/system/batocera.conf'
check "patched scripts still parse" 'sh -n ${T}/t1/etc/init.d/S60nfs && sh -n ${T}/t1/usr/share/batocera/services/syncthing'

echo "== refuses when the upstream text is not there (nothing patched silently)"
make_target "${T}/t2"; sed -i 's/^veto files.*/veto files = \/different\//' "${T}/t2/etc/samba/smb.conf"
OUT=$("${HARDEN}" "${T}/t2" 2>&1); RC=$?
check "changed upstream veto line -> exit 1 with a clear message" '[ "${RC}" = 1 ] && echo "${OUT}" | grep -q "Upstream changed"'
make_target "${T}/t3"; sed -i 's/Start daemons/Starting all daemons/' "${T}/t3/etc/init.d/S60nfs"
"${HARDEN}" "${T}/t3" >/dev/null 2>&1; RC=$?
check "changed upstream NFS script -> exit 1" '[ "${RC}" = 1 ]'
make_target "${T}/t4"; rm -f "${T}/t4/usr/share/batocera/services/syncthing"
"${HARDEN}" "${T}/t4" >/dev/null 2>&1; RC=$?
check "a missing file -> exit 1" '[ "${RC}" = 1 ]'
"${HARDEN}" "${T}/does-not-exist" >/dev/null 2>&1; RC=$?
check "a missing target folder -> exit 2" '[ "${RC}" = 2 ]'

echo "== the patched NFS script: does it start only when something is exported?"
export NFS_MARKER="${T}/nfs-started"
EXP="${T}/exports"
runnfs() { rm -f "${NFS_MARKER}"; sed "s|/etc/exports|${EXP}|g" "${T}/t1/etc/init.d/S60nfs" > "${T}/nfs-run.sh"; PATH="${T}/stubs:${PATH}" sh "${T}/nfs-run.sh" start > "${T}/nfs.out" 2>&1; }
mkdir -p "${T}/stubs"; printf '#!/bin/sh\nexit 0\n' > "${T}/stubs/rpc.statd"; chmod +x "${T}/stubs/rpc.statd"
: > "${EXP}"; runnfs
check "empty /etc/exports: the NFS server is not started" '[ ! -e ${NFS_MARKER} ] && grep -q "not starting" ${T}/nfs.out'
printf '# only a comment\n\n' > "${EXP}"; runnfs
check "only comments and blank lines: not started" '[ ! -e ${NFS_MARKER} ]'
rm -f "${EXP}"; runnfs
check "no exports file at all: not started" '[ ! -e ${NFS_MARKER} ]'
printf '/userdata/roms 192.168.1.0/24(ro)\n' > "${EXP}"; runnfs
check "a real export: the server starts as before" '[ -e ${NFS_MARKER} ]'

echo "== the patched Syncthing script: which address does it choose?"
runsync() { # <value returned for system.syncthing.lan> <value for system.security.enabled>
    printf '#!/bin/sh\ncase "$1" in system.syncthing.lan) echo "%s";; system.security.enabled) echo "%s";; esac\n' "$1" "$2" > "${T}/stubs/bsg"; chmod +x "${T}/stubs/bsg"
    sed "s|/usr/bin/batocera-settings-get|${T}/stubs/bsg|g" "${T}/t1/usr/share/batocera/services/syncthing" > "${T}/sync-run.sh"
    sh "${T}/sync-run.sh" 2>&1
}
check "default (nothing set): local only" '[ "$(runsync "" "")" = "GUI=http://127.0.0.1:8384" ]'
check "system.syncthing.lan=1: open to the network, as before" '[ "$(runsync 1 "")" = "GUI=http://0.0.0.0:8384" ]'
check "system.syncthing.lan=0: local only" '[ "$(runsync 0 "")" = "GUI=http://127.0.0.1:8384" ]'
check "upstream security option on: still local only" '[ "$(runsync "" 1)" = "GUI=http://127.0.0.1:8384" ]'

echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
