#!/bin/bash
# Test the OctaneOS patches to configgen (board/batocera/allwinner/a733/configgen-patches/): they apply to the configgen source of the Batocera
# submodule, apply a second time as "already applied", the result compiles, and the Amiga save logic behaves (default profile adopts the old
# shared saves by COPYING, a named profile starts empty, a failed copy leaves nothing half done).  Runs on copies in a throw-away folder.
# The Batocera submodule is not checked out in CI: then the source-dependent checks are skipped (build.sh applies the patches for real).
# Usage: scripts/test-configgen-patches.sh        exit status 0 = all tests passed
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PDIR="${REPO_ROOT}/board/batocera/allwinner/a733/configgen-patches"
SRC="${OCTANE_CONFIGGEN_SRC:-${REPO_ROOT}/batocera/package/batocera/core/batocera-configgen/configgen}"
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT
PASS=0; FAIL=0; SKIP=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; fi; }

echo "== the patch files"
check "there is at least one patch" 'ls "${PDIR}"/*.patch >/dev/null 2>&1'
if [ ! -d "${SRC}/configgen/generators/amiberry" ]; then
    echo "  SKIP  the Batocera submodule is not checked out: source-dependent checks skipped"; SKIP=1
else
    # the copy sits DEEP inside a repository, like the real one inside the Batocera submodule
    mkdir -p "${T}/repo/package/x"; cp -a "${SRC}" "${T}/repo/package/x/configgen"; rm -rf "${T}/repo/package/x/configgen/.git"
    (cd "${T}/repo" && git init -q . && git add -A >/dev/null 2>&1 && git -c user.name=t -c user.email=t@t commit -qm base >/dev/null 2>&1)
    CG="${T}/repo/package/x/configgen"
    echo "== applying to a copy of the real source"
    OUT="$("${REPO_ROOT}/scripts/apply-es-patches.sh" "${CG}" "${PDIR}" 2>&1)"; RC=$?
    check "every patch applies to the configgen source" '[ "${RC}" = 0 ] && echo "${OUT}" | grep -q "applied: 0001"'
    OUT="$("${REPO_ROOT}/scripts/apply-es-patches.sh" "${CG}" "${PDIR}" 2>&1)"
    check "...and a second run says already applied" 'echo "${OUT}" | grep -q "already applied: 0001"'
    check "the patched Amiberry generator compiles" 'python3 -I -m py_compile "${CG}/configgen/generators/amiberry/amiberryGenerator.py"'

    echo "== the Amiga save logic"
    cat > "${T}/logic.py" <<'PY'
import ast, logging, os, shutil, sys, tempfile
from pathlib import Path
src = open(sys.argv[1]).read()
tree = ast.parse(src)
fn = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == '_adopt_legacy_saves')
code = ast.get_source_segment(src, fn)
def run(saves_dir, legacy_dir, fail=False):
    g = {'Path': Path, 'shutil': shutil, '_logger': logging.getLogger('t'), '_SAVES_DIR': saves_dir, '_LEGACY_SAVES_DIR': legacy_dir}
    if fail:
        class S:  # a copytree that fails halfway, leaving a half-made folder
            @staticmethod
            def copytree(a, b):
                os.makedirs(b); open(os.path.join(b, 'half'), 'w').write('x'); raise OSError('disk full')
            rmtree = staticmethod(shutil.rmtree)
        g['shutil'] = S
    exec(code, g)
    logging.disable(logging.CRITICAL)
    g['_adopt_legacy_saves']()
ok = True
def expect(name, cond):
    global ok
    print(('PASS  ' if cond else 'FAIL  ') + name); ok = ok and cond
with tempfile.TemporaryDirectory() as d:
    d = Path(d)
    def fresh():
        shutil.rmtree(d / 'userdata', ignore_errors=True)
        legacy = d / 'userdata/saves/amiga'; legacy.mkdir(parents=True); (legacy / 'disk1.adf').write_text('OLD')
        return legacy
    legacy = fresh(); default = d / 'userdata/profiles/.default/saves/amiga'
    run(default, legacy)
    expect('the default profile adopts the shared saves (copied)', (default / 'disk1.adf').read_text() == 'OLD')
    expect('the originals are untouched', (legacy / 'disk1.adf').read_text() == 'OLD')
    (default / 'disk1.adf').write_text('NEW'); run(default, legacy)
    expect('a second run never overwrites the profile\'s own saves', (default / 'disk1.adf').read_text() == 'NEW')
    legacy = fresh(); named = d / 'userdata/profiles/amy/saves/amiga'
    run(named, legacy)
    expect('a named profile starts empty', not named.exists())
    legacy = fresh(); run(legacy, legacy)
    expect('no profile in use (same folder): nothing happens', (legacy / 'disk1.adf').read_text() == 'OLD')
    legacy = fresh(); default = d / 'userdata/profiles/.default/saves/amiga'
    run(default, legacy, fail=True)
    expect('a failed copy leaves nothing half done and the originals intact', not default.exists() and (legacy / 'disk1.adf').read_text() == 'OLD')
    shutil.rmtree(d / 'userdata'); run(d / 'userdata/profiles/.default/saves/amiga', d / 'userdata/saves/amiga')
    expect('no shared saves at all: nothing happens, nothing created', not (d / 'userdata').exists())
sys.exit(0 if ok else 1)
PY
    LOUT="$(python3 -I "${T}/logic.py" "${CG}/configgen/generators/amiberry/amiberryGenerator.py" 2>&1)"; LRC=$?
    while IFS= read -r l; do case "$l" in PASS*) PASS=$((PASS+1)); echo "  $l";; FAIL*) FAIL=$((FAIL+1)); echo "  $l";; esac; done <<< "${LOUT}"
    [ "${LRC}" = 0 ] || { [ "${FAIL}" -gt 0 ] || { FAIL=$((FAIL+1)); echo "  FAIL  logic test crashed: ${LOUT}"; }; }
fi
echo; echo "${PASS} passed, ${FAIL} failed$([ "${SKIP}" = 1 ] && echo ', source checks skipped')"
[ "${FAIL}" -eq 0 ]
