#!/usr/bin/env bash

# Prepend ~/.agents/$AGENT_NAME/.local/bin/ onto PATH so the agent-local
# patched claude binary wins over mise's claude shim. The patcher writes
# (and atomically symlinks) `claude` into this dir; without prepending it
# here, the mise-resolved claude (npm:@anthropic-ai/claude-code) wins on
# PATH and channel-allowlist patching is skipped.
#
# Runs AFTER 01_mise-activate.sh — ordering matters: the prepend below has
# to happen after mise has already amended PATH so that this directory ends
# up at the FRONT.
#
# cross-agent-consistency.md R2.

set -euo pipefail

: "${ROOT_DIR:?Environment variable ROOT_DIR must be set}"
# shellcheck source=../bin/lib/stdlib.sh
source "${ROOT_DIR}/bin/lib/stdlib.sh"

# Derive AGENT_NAME from the repo dir (.ai-agent-<name>) unless one is
# already exported. Single source of truth — keeps this rc agent-agnostic.
AGENT_NAME_LOCAL="${AGENT_NAME:-$(basename "${ROOT_DIR}" | sed 's/^\.ai-agent-//')}"
AGENT_LOCAL_BIN="${HOME}/.agents/${AGENT_NAME_LOCAL}/.local/bin"

# Ensure the directory exists so PATH entries that reference it don't fail
# silently. The directory is created by the launcher's patcher when the
# patched claude is built.
mkdir -p "${AGENT_LOCAL_BIN}"

# Prepend (later additions to PATH win when commands are resolved).
export PATH="${AGENT_LOCAL_BIN}:${PATH}"

if_debug echo "Prepended ${AGENT_LOCAL_BIN} to PATH"
