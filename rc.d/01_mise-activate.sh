#!/usr/bin/env bash

set -euo pipefail

# ensure root_dir is set
: "${ROOT_DIR:?Environment variable ROOT_DIR must be set}"
# shellcheck source=./bin/lib/stdlib.sh
source "${ROOT_DIR}"/bin/lib/stdlib.sh

cd "${ROOT_DIR}"

# activate mise environment
# check to see that mise is installed.
if command -v mise &> /dev/null; then

    # self-update intentionally not run; mise version is pinned via mise.toml
    # Skip `mise trust` if config is already trusted — it's a no-op anyway,
    # but the echo is just noise on every restart. `mise trust --show` prints
    # `<path>: trusted` for trusted configs and `<path>: untrusted` otherwise,
    # so anchoring on `: trusted$` distinguishes the two reliably.
    if mise trust --show 2>&1 | grep -qE ': trusted$'; then
        : # already trusted, silent no-op
    else
        echo "[mise] trusting config..."
        mise trust
    fi
    # `mise install -y` is a no-op when every pinned tool is already
    # installed, so we let mise self-gate rather than maintaining a sentinel.
    # First restart after an XDG_DATA_HOME change (or new mise.toml) will pay
    # the actual install cost; steady-state is fast.
    mise_toml="${ROOT_DIR}/mise.toml"
    echo "[mise] installing tools..."
    mise install -y
    echo "[mise] tools ready"

    # Post-install: print a human-readable summary of available updates
    # (cross-agent-consistency.md L27). Filter to tools sourced from this
    # repo's mise.toml only — global config drift is none of our business.
    if outdated_json="$(mise outdated --json 2>/dev/null)" && [[ -n "${outdated_json}" && "${outdated_json}" != "{}" ]]; then
        updates="$(printf '%s' "${outdated_json}" | jq -r --arg path "${mise_toml}" '
            to_entries
            | map(select(.value.source.path == $path))
            | map(select(.value.current and .value.latest and .value.current != .value.latest))
            | .[]
            | "  - \(.key)\t\(.value.current) -> \(.value.latest)"
        ' 2>/dev/null)"
        if [[ -n "${updates}" ]]; then
            {
                echo "Updates available for the following tools:"
                printf '%s\n' "${updates}" | column -t -s $'\t'
            } >&2
        fi
    fi

    # if mise's default resolution is a function, then mise is already activated.
    eval "$(mise activate bash)"
    # Also export the resolved tool install dirs into PATH. `mise activate`
    # alone only adds shims; `mise env -s bash` prepends the actual install
    # directories. Without this, direnv's exported PATH falls back to the
    # parent shell's snapshot, which on a long-lived launcher loop carries
    # stale claude-utils install dirs from the FIRST launch — and the bug
    # docs/specs/start-agent.md describes (R5) reappears on every restart.
    eval "$(mise env -s bash)"
else
    # mise is not installed, error and exit
    # TODO: try and re-use this logic with the SessionStart hook
    echo "Error: mise is not installed. Please install mise to proceed."
    echo "   see : https://mise.jdx.dev/cli/install.html"
    exit 1
fi

# Watch mise.toml (NOT .mise.toml) — direnv silently no-ops on a watch_file
# pointing at a path that doesn't exist, so the dot-prefixed variant looked
# fine but never triggered reloads on changes. cross-agent-consistency.md R1.
watch_file "${ROOT_DIR}/mise.toml"
