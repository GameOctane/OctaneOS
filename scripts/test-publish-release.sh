#!/bin/bash
# Test scripts/publish-release.sh with a fake gh, curl, git, image check and version bump.
# Nothing here touches GitHub or the repo.
# Usage: scripts/test-publish-release.sh        exit status 0 = all tests passed
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLISH="${REPO_ROOT}/scripts/publish-release.sh"
T="$(mktemp -d)"
[ -n "${T}" ] && [ -d "${T}" ] || { echo "cannot create a temporary folder" >&2; exit 2; }
trap 'rm -rf "${T:?}"' EXIT

PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; fi; }

mkdir -p "${T}/bin"
export CALLS="${T}/calls.log" STORE="${T}/store" PUBLIC="${T}/public"

cat > "${T}/bin/fakegh" <<'FAKE'
#!/bin/bash
echo "gh $*" >> "${CALLS}"
case "$1 $2" in
    "auth status") exit 0 ;;
    "release view")
        tag="$3"; [ -d "${STORE}/${tag}" ] || exit 1
        if [[ "$*" == *"--json assets"* ]]; then
            for f in "${STORE}/${tag}/files/"*; do printf '%s\t%s\n' "$(basename "$f")" "$(stat -c %s "$f")"; done
        fi
        exit 0 ;;
    "release create")
        tag="$3"; shift 3; files=()
        while [ $# -gt 0 ]; do
            case "$1" in
                --repo|--target|--title|--notes-file) shift 2 ;;
                --draft) shift ;;
                *) files+=("$1"); shift ;;
            esac
        done
        mkdir -p "${STORE}/${tag}/files"; cp "${files[@]}" "${STORE}/${tag}/files/"; echo draft > "${STORE}/${tag}/state"
        [ -n "${FAKE_TRUNCATE:-}" ] && truncate -s -1 "${STORE}/${tag}/files/${FAKE_TRUNCATE}"
        [ -n "${FAKE_CORRUPT_STORED:-}" ] && echo x >> "${STORE}/${tag}/files/${FAKE_CORRUPT_STORED}"
        exit 0 ;;
    "release download")
        tag="$3"; shift 3; dir=""; pat=""
        while [ $# -gt 0 ]; do
            case "$1" in --repo) shift 2 ;; --dir) dir="$2"; shift 2 ;; --pattern) pat="$2"; shift 2 ;; *) shift ;; esac
        done
        cp "${STORE}/${tag}/files/${pat}" "${dir}/${pat}"; exit 0 ;;
    "release edit")
        tag="$3"; echo published > "${STORE}/${tag}/state"
        mkdir -p "${PUBLIC}"; cp "${STORE}/${tag}/files/"* "${PUBLIC}/"
        [ -n "${FAKE_PUBLIC_BAD:-}" ] && echo wrong > "${PUBLIC}/boot.tar.xz.md5"
        exit 0 ;;
    "release delete") tag="$3"; rm -rf "${STORE:?}/${tag:?}"; exit 0 ;;
esac
exit 1
FAKE
cat > "${T}/bin/fakecurl" <<'FAKE'
#!/bin/bash
out=""; head=0; url=""
while [ $# -gt 0 ]; do
    case "$1" in -o) out="$2"; shift 2 ;; -*I*) head=1; shift ;; -*) shift ;; *) url="$1"; shift ;; esac
done
src="${PUBLIC}/$(basename "${url}")"; [ -f "${src}" ] || exit 22
if [ "${head}" = 1 ]; then printf 'HTTP/2 200\r\ncontent-length: %s\r\n\r\n' "$(stat -c %s "${src}")"; else cp "${src}" "${out}"; fi
FAKE
cat > "${T}/bin/fakecheck" <<'FAKE'
#!/bin/bash
echo "check-image $*" >> "${CALLS}"
[ "${FAKE_CHECK:-pass}" = "pass" ]
FAKE
cat > "${T}/bin/fakebump" <<'FAKE'
#!/bin/bash
echo "bump $*" >> "${CALLS}"
FAKE
cat > "${T}/bin/fakegit" <<'FAKE'
#!/bin/bash
echo "git $*" >> "${CALLS}"
case "$1" in
    rev-parse) echo abc1234def ;;
    status) [ -n "${FAKE_DIRTY:-}" ] && echo " M scripts/build.sh"; echo " m batocera"; exit 0 ;;
    *) exit 0 ;;
esac
FAKE
chmod +x "${T}"/bin/*

# a finished build with consistent files
new_build() {
    rm -rf "${T:?}/out" "${T:?}/store" "${T:?}/public"; : > "${CALLS}"
    local d="${T}/out/images/batocera/images/cubie-a7s"
    mkdir -p "${d}" "${T}/out/target/usr/share/batocera"
    echo "0.9.1" > "${T}/out/target/usr/share/batocera/octaneos.version"
    head -c 40000 /dev/urandom > "${d}/boot.tar.xz"; head -c 50000 /dev/urandom > "${d}/OctaneOS-a733-cubie-a7s-0.9.1-20261010.img.gz"
    local f
    for f in boot.tar.xz OctaneOS-a733-cubie-a7s-0.9.1-20261010.img.gz; do
        md5sum "${d}/${f}" | awk '{print $1}' > "${d}/${f}.md5"; sha256sum "${d}/${f}" | awk '{print $1}' > "${d}/${f}.sha256"
    done
    ( cd "${d}" && sha256sum boot.tar.xz OctaneOS-*.img.gz > SHA256SUMS )
    cat > "${T}/notes.md" <<'EOF'
## Compatibility
- **Update over the air:** yes
- **Back up first:** no
- **Needs a fresh install:** no
EOF
}

run() {
    OUT_TXT=$(OCTANE_OUT="${T}/out" OCTANE_GH="${T}/bin/fakegh" OCTANE_CURL="${T}/bin/fakecurl" \
        OCTANE_CHECK_IMAGE="${T}/bin/fakecheck" OCTANE_BUMP="${T}/bin/fakebump" OCTANE_GIT="${T}/bin/fakegit" \
        OCTANE_RETRY_WAIT=0 bash "${PUBLISH}" "$@" 2>&1)
    RC=$?
}
called() { grep -q -- "$1" "${CALLS}"; }
line_of() { grep -n "$1" "${CALLS}" | head -1 | cut -d: -f1; }
no_publish() { ! called "release create" && ! called "release edit" && ! called "^bump"; }

echo "== a normal release"
new_build; run --notes "${T}/notes.md"
check "exit status 0" '[ "${RC}" = 0 ]'
check "the build is checked in release mode first" 'called "check-image --release"'
check "order: check, view, create draft, view assets, download, publish, bump, commit" '
  [ "$(line_of "check-image")" -lt "$(line_of "release view v0.9.1 --repo GameOctane/OctaneOS$")" ] &&
  [ "$(line_of "release create")" -lt "$(line_of "json assets")" ] &&
  [ "$(line_of "json assets")" -lt "$(line_of "release download")" ] &&
  [ "$(line_of "release download")" -lt "$(line_of "release edit")" ] &&
  [ "$(line_of "release edit")" -lt "$(line_of "^bump")" ] &&
  [ "$(line_of "^bump")" -lt "$(line_of "git commit")" ]'
check "created as a draft, then published as the latest release" 'called "release create v0.9.1 .*--draft" && called "release edit v0.9.1 .*--draft=false --latest"'
check "all seven files were attached" '[ "$(ls ${STORE}/v0.9.1/files | wc -l)" = 7 ]'
check "the release records the commit it was built from" 'called "--target abc1234def"'
check "it does not push anything" '! called "git push"'
check "it says the version file must reach main" 'echo "${OUT_TXT}" | grep -q "no device is told"'

echo "== refused before anything is created"
new_build; run --notes "${T}/notes.md" --dry-run
check "dry run: all checks, nothing published" '[ "${RC}" = 0 ] && no_publish && echo "${OUT_TXT}" | grep -q "DRY RUN"'
new_build; FAKE_CHECK=fail run --notes "${T}/notes.md"
check "image check fails (for example a developer key) -> nothing published" '[ "${RC}" = 1 ] && no_publish'
new_build; run
check "no --notes -> refused" '[ "${RC}" = 1 ] && no_publish && echo "${OUT_TXT}" | grep -q "notes FILE is required"'
new_build; sed -i 's/yes$/yes \/ no/' "${T}/notes.md"; run --notes "${T}/notes.md"
check "release notes with template placeholders -> refused" '[ "${RC}" = 1 ] && no_publish && echo "${OUT_TXT}" | grep -q placeholders'
new_build; echo "just words" > "${T}/notes.md"; run --notes "${T}/notes.md"
check "release notes without the Compatibility block -> refused" '[ "${RC}" = 1 ] && no_publish && echo "${OUT_TXT}" | grep -q "no Compatibility line"'
new_build; rm -f "${T:?}/out/images/batocera/images/cubie-a7s/boot.tar.xz.md5"; run --notes "${T}/notes.md"
check "a missing .md5 -> refused (devices would refuse it)" '[ "${RC}" = 1 ] && no_publish && echo "${OUT_TXT}" | grep -q "missing or empty"'
new_build; echo 00000000000000000000000000000000 > "${T}/out/images/batocera/images/cubie-a7s/boot.tar.xz.md5"; run --notes "${T}/notes.md"
check "an .md5 that does not match the file -> refused" '[ "${RC}" = 1 ] && no_publish && echo "${OUT_TXT}" | grep -q "does not match"'
new_build; echo "not a version" > "${T}/out/target/usr/share/batocera/octaneos.version"; run --notes "${T}/notes.md"
check "an unreadable version -> refused" '[ "${RC}" = 1 ] && no_publish'
new_build; FAKE_DIRTY=1 run --notes "${T}/notes.md"
check "uncommitted changes -> refused" '[ "${RC}" = 1 ] && no_publish && echo "${OUT_TXT}" | grep -q uncommitted'
new_build; FAKE_DIRTY=1 run --notes "${T}/notes.md" --allow-dirty
check "uncommitted changes with --allow-dirty -> allowed" '[ "${RC}" = 0 ]'
new_build; mkdir -p "${STORE}/v0.9.1/files"; run --notes "${T}/notes.md"
check "a release for this version already exists -> refused, never overwritten" '[ "${RC}" = 1 ] && ! called "release create" && echo "${OUT_TXT}" | grep -q "never overwritten"'

echo "== failures after the draft exists"
new_build; FAKE_TRUNCATE=boot.tar.xz run --notes "${T}/notes.md"
check "GitHub holds a file with the wrong size -> draft deleted, not published, no bump" '[ "${RC}" = 1 ] && called "release delete v0.9.1" && ! called "release edit" && ! called "^bump" && [ ! -d "${STORE}/v0.9.1" ]'
new_build; FAKE_CORRUPT_STORED=boot.tar.xz.md5 run --notes "${T}/notes.md"
check "a checksum file on GitHub differs from the local one -> draft deleted, not published" '[ "${RC}" = 1 ] && called "release delete v0.9.1" && ! called "release edit" && ! called "^bump"'

echo "== failure after publishing"
new_build; FAKE_PUBLIC_BAD=1 run --notes "${T}/notes.md"
check "public download differs -> exits non-zero, NO version bump, and says devices are not told" '[ "${RC}" = 1 ] && called "release edit" && ! called "^bump" && ! called "git commit" && echo "${OUT_TXT}" | grep -q "devices are not being told"'
check "a published release is NOT deleted when only the public check fails" '! called "release delete"'

echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
