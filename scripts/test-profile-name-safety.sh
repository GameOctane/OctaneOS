#!/bin/bash
# The profile screen of EmulationStation used to paste a typed name into a shell command (a quote in a display name broke it, and a crafted
# name could run commands).  Patch 0005 replaces that: shellQuote() for the names handed to batocera-profiles, and writeDisplayName() which
# edits the conf file without a shell.  This test pulls those two C++ functions out of the patch, compiles them on their own and feeds them
# hostile names.  Needs g++ (skipped, not passed, without it).
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH="$(ls "${REPO_ROOT}"/board/batocera/allwinner/a733/es-patches/0005-*.patch)"
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT; PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; fi; }
command -v g++ >/dev/null || { echo "g++ not found: test skipped"; exit 0; }
{ printf '#include <string>\n#include <cstdio>\n#include <cstring>\n#include <cstdlib>\n'
  ADDED="$(grep '^+' "${PATCH}" | grep -v '^+++' | sed 's/^+//')"
  printf '%s\n' "${ADDED}" | sed -n '/^static std::string shellQuote/,/^}/p'
  printf '%s\n' "${ADDED}" | sed -n '/^static bool writeDisplayName/,/^}/p'
  cat <<'EOS'
int main(int argc, char** argv)
{
	if (argc < 3) return 2;
	if (std::string(argv[1]) == "q") { puts(shellQuote(argv[2]).c_str()); return 0; }
	return writeDisplayName(argv[2], argv[3]) ? 0 : 1;
}
EOS
} > "${T}/t.cpp"
check "the two functions compile" 'g++ -std=c++17 -Wall -Wextra -Werror -o "${T}/t" "${T}/t.cpp" 2>"${T}/err" || { cat "${T}/err"; false; }'
[ -x "${T}/t" ] || { echo "${PASS} passed, ${FAIL} failed"; exit 1; }
printf 'username=bob\napikey=KEY\ndisplay_name=Old\nra_enabled=1' > "${T}/c.conf"
"${T}/t" w "${T}/c.conf" "Mom's name"
check "a name with a quote is saved, other settings are kept, the old name is replaced" 'grep -qx "display_name=Mom.s name" "${T}/c.conf" && grep -qx "username=bob" "${T}/c.conf" && grep -qx "apikey=KEY" "${T}/c.conf" && grep -qx "ra_enabled=1" "${T}/c.conf" && [ "$(grep -c "^display_name=" "${T}/c.conf")" = 1 ]'
"${T}/t" w "${T}/c.conf" "x\$(touch ${T}/PWNED)"
check "a name that looks like a shell command runs nothing" '[ ! -e "${T}/PWNED" ]'
"${T}/t" w "${T}/c.conf" "$(printf 'A\nra_enabled=0\nB')"
check "a new line in a name cannot add a fake setting" '[ "$(grep -c "^ra_enabled=" "${T}/c.conf")" = 1 ] && grep -qx "ra_enabled=1" "${T}/c.conf"'
"${T}/t" w "${T}/c.conf" "$(printf 'x%.0s' $(seq 1 80))"
check "a name is cut to 40 characters" '[ "$(grep "^display_name=" "${T}/c.conf" | cut -d= -f2- | tr -d "\n" | wc -c)" = 40 ]'
check "no temporary file is left behind" '[ ! -e "${T}/c.conf.tmp" ]'
"${T}/t" w "${T}/nowhere/c.conf" "x"; check "an unwritable place reports failure (exit 1)" '[ $? = 1 ]'
check "shellQuote turns a quote into the close-escape-open form" '[ "$("${T}/t" q "a'"'"'b")" = "'"'"'a'"'"'\\'"'"''"'"'b'"'"'" ]'
check "shellQuote keeps \$( ) inert (it is inside single quotes)" '[ "$(sh -c "printf %s $("${T}/t" q "\$(echo HACK)")")" = "\$(echo HACK)" ]'
echo; echo "${PASS} passed, ${FAIL} failed"; [ "${FAIL}" -eq 0 ]
