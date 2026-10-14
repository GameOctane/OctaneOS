#!/bin/bash
# Helpers for pinning a git checkout to an exact commit.  Sourced by scripts/setup-kernel-66.sh and the tests.

# read_pin FILE KEY  -> value of KEY=VALUE in FILE (empty if missing); ignores comments and blank lines
read_pin() {
    sed -n "s/^$2=\(.*\)$/\1/p" "$1" | head -n 1
}

# pin_checkout DIR REPO BRANCH COMMIT
# Makes DIR a checkout of exactly COMMIT (detached).  Clones nothing but that commit when the server allows it,
# otherwise the last 200 commits of BRANCH.  Sets PIN_CHANGED=1 when it had to move an existing checkout.
# Returns non-zero, with a message, if the commit is not a full hash, cannot be found, or does not end up checked out.
pin_checkout() {
    local dir="$1" repo="$2" branch="$3" sha="$4" head
    if ! [[ "${sha}" =~ ^[0-9a-f]{40}$ ]]; then
        echo "ERROR: the pin for ${repo} is not a full 40-character commit hash: '${sha}'" >&2
        return 1
    fi
    if [ ! -d "${dir}/.git" ]; then
        mkdir -p "${dir}"
        git -C "${dir}" init -q || return 1
        git -C "${dir}" remote add origin "${repo}" || return 1
    fi
    head="$(git -C "${dir}" rev-parse -q --verify HEAD 2>/dev/null || true)"
    if [ "${head}" != "${sha}" ]; then
        echo "  Fetching pinned commit ${sha:0:12} of ${repo} ..."
        if ! git -C "${dir}" fetch -q --depth=1 origin "${sha}" 2>/dev/null; then
            echo "  (the server refused a fetch by hash; fetching the last 200 commits of ${branch})"
            git -C "${dir}" fetch -q --depth=200 origin "${branch}" || return 1
        fi
        if ! git -C "${dir}" cat-file -e "${sha}^{commit}" 2>/dev/null; then
            echo "ERROR: commit ${sha} was not found in ${repo} (${branch}). Check ${BASH_SOURCE[0]%/*}/../board/batocera/allwinner/a733/kernel-sources.pin" >&2
            return 1
        fi
        git -C "${dir}" checkout -q -f --detach "${sha}" || return 1
        PIN_CHANGED=1
    fi
    if [ "$(git -C "${dir}" rev-parse HEAD)" != "${sha}" ]; then
        echo "ERROR: ${dir} is not at the pinned commit ${sha}" >&2
        return 1
    fi
    return 0
}
