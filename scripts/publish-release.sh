#!/bin/bash
# Publish a finished build as a GitHub release, in an order that cannot leave devices pointing at
# files that are not there yet.
#
# How devices find an update (see UPGRADING.md):
#   1. EmulationStation reads ota/cubie-a7s/stable/last/batocera.version from the main branch and
#      shows "update available" when it differs from the installed version;
#   2. on Update, batocera-upgrade downloads boot.tar.xz and its checksums from the latest release.
# So the version file is what announces an update, and the release is what delivers it.  This
# script makes the release complete and verified first, and only then bumps the version file:
#
#   1  check the build: scripts/check-image.sh --release (no developer SSH key, all checks pass)
#   2  check the files: all present, checksums consistent, the release notes filled in
#   3  refuse if this version already has a release (a release is never overwritten)
#   4  create the release as a DRAFT (invisible to devices) with every file attached
#   5  check what GitHub holds: every file the right size, the small checksum files identical
#   6  publish the draft as the latest release
#   7  check what a device would see: the public download addresses return the same files
#   8  only now bump the version file and commit it locally (YOU push it; that is the announcement)
#
# If a step fails the script stops.  Before step 6 the draft is deleted.  After step 6 the release
# is public but devices are not told about it, because the version file is not bumped.
#
# Usage: scripts/publish-release.sh --notes FILE [--dry-run] [--allow-dirty]
#   --notes FILE    release notes, with the Compatibility block filled in (docs/release-notes-template.md)
#   --dry-run       do steps 1 and 2, print the plan, publish nothing
#   --allow-dirty   allow uncommitted changes (the release records the commit it was built from)
#
# Variables starting with OCTANE_ exist so scripts/test-publish-release.sh can run this with a
# fake gh; do not set them for a real release.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${OCTANE_OUT:-${REPO_ROOT}/batocera/output/a733-cubie-a7s}"
IMG_DIR="${OUT}/images/batocera/images/cubie-a7s"
GH="${OCTANE_GH:-gh}"
CURL="${OCTANE_CURL:-curl}"
CHECK_IMAGE="${OCTANE_CHECK_IMAGE:-${REPO_ROOT}/scripts/check-image.sh}"
BUMP="${OCTANE_BUMP:-${REPO_ROOT}/scripts/release-ota-version.sh}"
REPO="${OCTANE_REPO:-GameOctane/OctaneOS}"
PUBLIC_BASE="${OCTANE_PUBLIC_BASE:-https://github.com/${REPO}/releases/latest/download}"
RETRY_WAIT="${OCTANE_RETRY_WAIT:-10}"

NOTES=""; DRY=0; DIRTY_OK=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --notes) NOTES="${2:-}"; shift 2 ;;
        --dry-run) DRY=1; shift ;;
        --allow-dirty) DIRTY_OK=1; shift ;;
        *) echo "unknown option: $1" >&2; sed -n '2,36p' "$0" >&2; exit 2 ;;
    esac
done

step() { printf '\n== %s\n' "$*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }
repo_git() { if [ -n "${OCTANE_GIT:-}" ]; then "${OCTANE_GIT}" "$@"; else git -C "${REPO_ROOT}" "$@"; fi; }

DRAFT_CREATED=0
cleanup_draft() {
    if [ "${DRAFT_CREATED}" = "1" ]; then
        echo "Deleting the draft release ${TAG} so nothing half-finished is left on GitHub..." >&2
        "${GH}" release delete "${TAG}" --repo "${REPO}" --yes >/dev/null 2>&1 || echo "WARNING: could not delete the draft ${TAG}; delete it by hand." >&2
        DRAFT_CREATED=0
    fi
}
on_exit() { local rc=$?; [ "${rc}" -ne 0 ] && cleanup_draft; return "${rc}"; }
trap on_exit EXIT

TAG=""
[ -n "${NOTES}" ] || die "--notes FILE is required (see docs/release-notes-template.md)"

# ---------------------------------------------------------------- 1. check the build
step "1. checking the build"
[ -d "${IMG_DIR}" ] || die "no build output at ${IMG_DIR}"
VERSION="$(tr -d '\r\n' < "${OUT}/target/usr/share/batocera/octaneos.version" 2>/dev/null || true)"
[[ "${VERSION}" =~ ^[0-9]+(\.[0-9]+)*$ ]] || die "cannot read a version like 0.6.9 from the build (got '${VERSION}')"
TAG="v${VERSION}"
echo "version ${VERSION}, release tag ${TAG}"
"${CHECK_IMAGE}" --release || die "the image check failed, nothing was published"

# ---------------------------------------------------------------- 2. check the files
step "2. checking the files and the release notes"
IMG="$(basename "$(ls "${IMG_DIR}"/OctaneOS-*.img.gz 2>/dev/null | head -1)" 2>/dev/null || true)"
[ -n "${IMG}" ] || die "no OctaneOS-*.img.gz in ${IMG_DIR}"
ASSETS=(boot.tar.xz boot.tar.xz.md5 boot.tar.xz.sha256 "${IMG}" "${IMG}.md5" "${IMG}.sha256" SHA256SUMS)
for a in "${ASSETS[@]}"; do
    [ -s "${IMG_DIR}/${a}" ] || die "missing or empty: ${IMG_DIR}/${a}"
done
for f in boot.tar.xz "${IMG}"; do
    want_md5="$(awk 'NR==1 {print tolower($1)}' "${IMG_DIR}/${f}.md5")"
    want_sha="$(awk 'NR==1 {print tolower($1)}' "${IMG_DIR}/${f}.sha256")"
    [ "$(md5sum "${IMG_DIR}/${f}" | awk '{print $1}')" = "${want_md5}" ] || die "${f}.md5 does not match ${f}"
    [ "$(sha256sum "${IMG_DIR}/${f}" | awk '{print $1}')" = "${want_sha}" ] || die "${f}.sha256 does not match ${f}"
done
( cd "${IMG_DIR}" && sha256sum -c --quiet SHA256SUMS ) || die "SHA256SUMS does not match the files"

[ -f "${NOTES}" ] || die "release notes file not found: ${NOTES}"
for need in "update over the air:" "back up first:" "needs a fresh install:"; do
    grep -qi "${need}" "${NOTES}" || die "the release notes have no Compatibility line '${need}'"
done
if grep -qE 'yes / no|<version>|<yes/no>|<link' "${NOTES}"; then
    die "the release notes still contain template placeholders (yes / no, <version>, <link ...>)"
fi

# Devices decide "is there an update?" by comparing version strings, so a release that is not NEWER
# than the latest one would never be offered to anyone on that version.
# gh prints GitHub's JSON error text on stdout when there is no release (404), so accept the output only
# when the call succeeded AND it looks like a version tag.
LATEST_TAG="$("${GH}" api "repos/${REPO}/releases/latest" --jq .tag_name 2>/dev/null)" || LATEST_TAG=""
[[ "${LATEST_TAG}" =~ ^v?[0-9]+(\.[0-9]+)*([-.+][0-9A-Za-z.+-]*)?$ ]] || LATEST_TAG=""
if [ -n "${LATEST_TAG}" ]; then
    NEWEST="$(printf '%s\n%s\n' "${LATEST_TAG#v}" "${VERSION}" | sort -V | tail -1)"
    if [ "${LATEST_TAG#v}" = "${VERSION}" ] || [ "${NEWEST}" != "${VERSION}" ]; then
        die "version ${VERSION} is not newer than the latest release ${LATEST_TAG}, so devices on ${LATEST_TAG#v} would not be offered it. Raise OCTANE_VERSION_STRING in post-build.sh and rebuild."
    fi
    echo "latest published release is ${LATEST_TAG}; ${VERSION} is newer"
else
    echo "no published release found on ${REPO} (first release)"
fi

COMMIT="$(repo_git rev-parse HEAD)"
if [ "${DIRTY_OK}" != "1" ]; then
    if repo_git status --porcelain --untracked-files=no | grep -vE '^ ?m? ?batocera$|^ M batocera$' | grep -q .; then
        die "uncommitted changes in the repo; commit them first or use --allow-dirty"
    fi
fi
echo "built from commit ${COMMIT}"
echo "files: ${ASSETS[*]}"

if [ "${DRY}" = "1" ]; then
    echo
    echo "DRY RUN: all checks passed. Nothing was published. A real run would now:"
    echo "  create draft ${TAG} on ${REPO}, verify it, publish it, verify the public downloads,"
    echo "  then bump the OTA version file and commit it locally."
    exit 0
fi

# ---------------------------------------------------------------- 3. never overwrite
step "3. making sure ${TAG} does not exist yet"
"${GH}" auth status >/dev/null 2>&1 || die "gh is not logged in (run: gh auth login)"
if "${GH}" release view "${TAG}" --repo "${REPO}" >/dev/null 2>&1; then
    die "a release ${TAG} already exists on ${REPO}; releases are never overwritten (bump the version)"
fi

# ---------------------------------------------------------------- 4. draft with every file
step "4. creating the draft release (devices cannot see it)"
UPLOAD=()
for a in "${ASSETS[@]}"; do UPLOAD+=("${IMG_DIR}/${a}"); done
"${GH}" release create "${TAG}" --repo "${REPO}" --draft --target "${COMMIT}" \
    --title "OctaneOS ${VERSION}" --notes-file "${NOTES}" "${UPLOAD[@]}" \
    || die "creating the draft failed"
DRAFT_CREATED=1

# ---------------------------------------------------------------- 5. check what GitHub holds
step "5. checking what GitHub holds"
HELD="$("${GH}" release view "${TAG}" --repo "${REPO}" --json assets --jq '.assets[] | [.name, .size] | @tsv')" \
    || die "cannot read the draft back from GitHub"
for a in "${ASSETS[@]}"; do
    have="$(printf '%s\n' "${HELD}" | awk -F'\t' -v n="${a}" '$1 == n {print $2}')"
    want="$(stat -c %s "${IMG_DIR}/${a}")"
    [ "${have}" = "${want}" ] || die "GitHub holds ${a} with size '${have}', expected ${want}"
done
echo "all ${#ASSETS[@]} files are present on GitHub with the right size"
TMP="$(mktemp -d)"
for a in boot.tar.xz.md5 boot.tar.xz.sha256 SHA256SUMS; do
    "${GH}" release download "${TAG}" --repo "${REPO}" --dir "${TMP}" --pattern "${a}" \
        || die "cannot download ${a} from the draft"
    cmp -s "${TMP}/${a}" "${IMG_DIR}/${a}" || die "${a} on GitHub differs from the local file"
done
rm -rf "${TMP:?}"
echo "the checksum files on GitHub are identical to the local ones"

# ---------------------------------------------------------------- 6. publish
step "6. publishing ${TAG} as the latest release"
"${GH}" release edit "${TAG}" --repo "${REPO}" --draft=false --latest || die "publishing failed"
DRAFT_CREATED=0

# ---------------------------------------------------------------- 7. what a device sees
step "7. checking what a device would download"
check_public() {
    local f len want
    for f in boot.tar.xz.md5 boot.tar.xz.sha256; do
        "${CURL}" -sfL "${PUBLIC_BASE}/${f}" -o "${TMP:-/dev/null}.pub" 2>/dev/null || return 1
        cmp -s "${TMP:-/dev/null}.pub" "${IMG_DIR}/${f}" || return 1
    done
    len="$("${CURL}" -sfIL "${PUBLIC_BASE}/boot.tar.xz" | tr -d '\r' | grep -i '^content-length:' | tail -1 | sed 's/^[^:]*: *//')"
    want="$(stat -c %s "${IMG_DIR}/boot.tar.xz")"
    [ "${len}" = "${want}" ]
}
TMP="$(mktemp -d)"
ok=0
for try in 1 2 3 4 5; do
    if check_public; then ok=1; break; fi
    echo "not visible yet (attempt ${try}/5); waiting ${RETRY_WAIT}s..."
    sleep "${RETRY_WAIT}"
done
rm -rf "${TMP:?}"
if [ "${ok}" != "1" ]; then
    echo "ERROR: ${TAG} is published, but the public download does not match the local files." >&2
    echo "       The OTA version file was NOT updated, so devices are not being told about this release." >&2
    echo "       Investigate before announcing it." >&2
    exit 1
fi
echo "the public downloads match the local files"

# ---------------------------------------------------------------- 8. announce
step "8. bumping the OTA version file (this is what tells devices)"
"${BUMP}" --skip-image-check || die "the release is public and verified, but bumping the version file failed"
repo_git add ota/cubie-a7s/stable/last/batocera.version
repo_git commit -q -m "release: OTA version ${VERSION}" || die "could not commit the version file"
echo
echo "${TAG} is published and verified."
echo "Devices will offer it once the version file is on the main branch:"
echo "  merge or push the commit 'release: OTA version ${VERSION}' to main."
echo "Until you do, no device is told about this release."
