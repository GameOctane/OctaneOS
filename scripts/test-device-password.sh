#!/bin/bash
# Test the device-password pieces in a throw-away folder (no board, no /boot, no /run): the OctaneOS S35securepasswd (SHA-512 login hash, Samba
# password passed safely, the reset-password file) and octane-device-password (status / set / skip / ask-again).  Batocera's own helpers are
# replaced by small fakes that keep their state in the scratch folder; openssl is the real one.
# Usage: scripts/test-device-password.sh        exit status 0 = all tests passed
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OV="${REPO_ROOT}/board/batocera/allwinner/a733/fsoverlay"
S35="${OV}/etc/init.d/S35securepasswd"; HELPER="${OV}/usr/bin/octane-device-password"
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT
BOOT="${T}/boot"; RUN="${T}/run"; SMB="${T}/smb"; CONF="${T}/batocera.conf"; FAKE="${T}/bin"; SMBIN="${T}/smb-input"
mkdir -p "${BOOT}" "${RUN}" "${FAKE}"
PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; fi; }

cat > "${FAKE}/batocera-settings-get" <<'EOS'
#!/bin/sh
grep "^$1=" "${FAKE_CONF}" 2>/dev/null | tail -1 | cut -d= -f2-
EOS
cat > "${FAKE}/batocera-settings-set" <<'EOS'
#!/bin/sh
grep -v "^$1=" "${FAKE_CONF}" > "${FAKE_CONF}.n" 2>/dev/null; echo "$1=$2" >> "${FAKE_CONF}.n"; mv "${FAKE_CONF}.n" "${FAKE_CONF}"
EOS
# batocera-config: getRootPassword gives "linux" when security is off, else the stored word; setRootPassword does nothing when security is off
cat > "${FAKE}/batocera-config" <<'EOS'
#!/bin/sh
sec="$(batocera-settings-get system.security.enabled)"
case "$1" in
  getRootPassword) if [ "${sec}" != "1" ]; then echo linux; exit 0; fi
                   w="$(grep -E '^[ 	]*rootshadowpassword[ 	]*=' "${FAKE_BOOT}/batocera-boot.conf" 2>/dev/null | sed 's/^[^=]*=//')"; [ -n "${w}" ] && printf '%s\n' "${w}" || exit 1 ;;
  setRootPassword) [ "${sec}" = "1" ] || exit 0
                   grep -vE '^[ 	]*rootshadowpassword' "${FAKE_BOOT}/batocera-boot.conf" > "${FAKE_BOOT}/b.n" 2>/dev/null
                   printf 'rootshadowpassword=%s\n' "${2:-generatedpw}" >> "${FAKE_BOOT}/b.n"; mv "${FAKE_BOOT}/b.n" "${FAKE_BOOT}/batocera-boot.conf" ;;
esac
EOS
cat > "${FAKE}/smbpasswd" <<'EOS'
#!/bin/sh
cat > "${FAKE_SMBIN}"
EOS
chmod +x "${FAKE}"/*
export FAKE_CONF="${CONF}" FAKE_BOOT="${BOOT}" FAKE_SMBIN="${SMBIN}" OCTANE_BOOT="${BOOT}" OCTANE_RUN="${RUN}" OCTANE_SMB_DIR="${SMB}" OCTANE_NO_REMOUNT=1
export OCTANE_S35="${S35}" PATH="${FAKE}:${PATH}"
: > "${CONF}"; echo "other=keep" > "${BOOT}/batocera-boot.conf"

boot() { sh "${S35}" start >/dev/null 2>&1; }
# does the root line of the generated shadow file verify against this password?
shadow_ok() { local h salt; h="$(sed -n 's/^root:\([^:]*\):.*/\1/p' "${RUN}/batocera.shadow")"; salt="$(echo "${h}" | cut -d'$' -f3)"
              [ "${h#\$6\$}" != "${h}" ] && [ "$(openssl passwd -6 -salt "${salt}" "$1")" = "${h}" ]; }
smb_in() { [ "$(sed -n 1p "${SMBIN}")" = "$1" ] && [ "$(sed -n 2p "${SMBIN}")" = "$1" ]; }

echo "== a device that never set a password: the default word, but with a modern hash"
boot
check "the login hash is SHA-512 (\$6\$) and verifies the default word" 'shadow_ok linux'
check "the file-share password is the default word too" 'smb_in linux'
check "the batocera user line is still written (needed for su)" 'grep -q "^batocera::::::::" "${RUN}/batocera.shadow"'
check "the first-boot screen should ask" '[ "$(sh "${HELPER}" status)" = ask ]'

echo "== setting a password"
OUT="$(echo short | sh "${HELPER}" set 2>&1)"; RC=$?
check "a password under 8 characters is refused, with a reason" '[ "${RC}" = 2 ] && echo "${OUT}" | grep -q "at least 8"'
check "...and nothing changed" '[ "$(sh "${HELPER}" status)" = ask ] && [ "$(batocera-settings-get system.security.enabled)" = "" ]'
OUT="$(printf 'abcdefgh\001' | sh "${HELPER}" set 2>&1)"; RC=$?
check "a password with a control character is refused" '[ "${RC}" = 2 ]'
PW='My pass%s%d\n word#1'
OUT="$(printf '%s\n' "${PW}" | sh "${HELPER}" set 2>&1)"; RC=$?
check "a good password (with spaces, % and a backslash) is accepted" '[ "${RC}" = 0 ] && [ "${OUT}" = "password set" ]'
check "...security is switched on and the screen no longer asks" '[ "$(sh "${HELPER}" status)" = set ] && [ "$(batocera-settings-get octane.password.prompted)" = 1 ]'
check "...it is applied at once: the login hash verifies the NEW password" 'shadow_ok "${PW}" && ! shadow_ok linux'
check "...and Samba gets the exact password, % and backslash included (the original script garbled these)" 'smb_in "${PW}"'
check "...and the default word no longer works for the login" '! shadow_ok linux'
boot
check "after a restart the same password is still in force" 'shadow_ok "${PW}" && smb_in "${PW}"'

echo "== the reset file"
: > "${BOOT}/reset-password"
boot
check "the reset file is removed" '[ ! -e "${BOOT}/reset-password" ]'
check "security is off again and the default word works" '[ "$(batocera-settings-get system.security.enabled)" = 0 ] && shadow_ok linux && smb_in linux'
check "the stored password is forgotten, other boot settings are kept" '! grep -q rootshadowpassword "${BOOT}/batocera-boot.conf" && grep -q "^other=keep" "${BOOT}/batocera-boot.conf"'
check "the first-boot screen asks again" '[ "$(sh "${HELPER}" status)" = ask ]'

echo "== skipping"
sh "${HELPER}" skip >/dev/null
check "skip: the screen does not ask again" '[ "$(sh "${HELPER}" status)" = skipped ]'
boot
check "...and the device stays on the default word" 'shadow_ok linux && smb_in linux'
sh "${HELPER}" ask-again
check "ask-again makes the screen ask once more" '[ "$(sh "${HELPER}" status)" = ask ]'

echo "== an existing device after an update (security was never touched)"
: > "${CONF}"; rm -f "${BOOT}/reset-password"; boot
check "it gets the screen once (status = ask)" '[ "$(sh "${HELPER}" status)" = ask ]'
check "...and nothing about its login changed until it chooses" 'shadow_ok linux'

echo "== usage"
sh "${HELPER}" bogus >/dev/null 2>&1; check "an unknown command is refused" '[ $? = 2 ]'

echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
