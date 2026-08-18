#!/bin/sh
# Seeds Codex + Claude Code into the real (host-shared) user home from the
# root-owned, build-time copies baked into this image under /root — avoids a
# network install on every fresh distrobox `assemble + enter` (which pays
# full cost per distinct $HOME, e.g. any box created with --home, not just
# once ever on a machine). Falls back to a live network install — always as
# the real user via runuser, never as root — if the /root seed is missing
# for any reason (e.g. an older image built before this script existed).
#
# Runs as root (distrobox-init's own init_hooks context, by design — copying
# and chown'ing needs root). Every file this script leaves behind under the
# real user's home is chown'd to that user before returning; nothing here is
# left root-owned.
#
# Usage (from distrobox.ini's init_hooks, once per container start):
#   /usr/local/libexec/toolbox-seed-install.sh "$container_user_name" "$container_user_home"
#
# Idempotent — each guard below only acts if its real target is missing, so
# repeat runs (every container start) are a handful of `-x` checks and no-op.

set -eu

USER_NAME="${1:?missing container user name}"
USER_HOME="${2:?missing container user home}"

# codex: same package payload for both profiles, seeded once at build time
# under /root/.codex, copied into whichever of the two real profile homes
# doesn't have it yet.
seed_or_fetch_codex() {
	target_home="$1"    # e.g. $USER_HOME/.codex or $USER_HOME/.codex-spark
	codex_home_env="$2" # CODEX_HOME to export for the network fallback

	[ -x "${target_home}/packages/standalone/current/codex" ] && return 0

	if [ -d /root/.codex/packages/standalone ]; then
		printf 'toolbox-seed-install: seeding codex into %s from /root copy\n' "${target_home}"
		mkdir -p "${target_home}"
		cp -a /root/.codex/packages "${target_home}/"
		chown -R "${USER_NAME}:${USER_NAME}" "${target_home}"
	else
		printf 'toolbox-seed-install: no /root seed for codex, installing over the network as %s\n' "${USER_NAME}"
		runuser -u "${USER_NAME}" -- env HOME="${USER_HOME}" CODEX_HOME="${codex_home_env}" CODEX_NON_INTERACTIVE=true \
			sh -c 'curl -fsSL https://chatgpt.com/codex/install.sh | sh'
	fi
}

seed_or_fetch_codex "${USER_HOME}/.codex" "${USER_HOME}/.codex"
seed_or_fetch_codex "${USER_HOME}/.codex-spark" "${USER_HOME}/.codex-spark"

# claude: one shared binary/version tree, no per-profile package split.
if [ ! -x "${USER_HOME}/.local/bin/claude" ]; then
	if [ -d /root/.local/share/claude/versions ]; then
		ver="$(ls /root/.local/share/claude/versions | sort -V | tail -1)"
		printf 'toolbox-seed-install: seeding claude %s into %s from /root copy\n' "${ver}" "${USER_HOME}"
		mkdir -p "${USER_HOME}/.local/share/claude/versions" "${USER_HOME}/.local/bin"
		cp -a "/root/.local/share/claude/versions/${ver}" "${USER_HOME}/.local/share/claude/versions/"
		ln -sf "${USER_HOME}/.local/share/claude/versions/${ver}" "${USER_HOME}/.local/bin/claude"
		chown -R "${USER_NAME}:${USER_NAME}" "${USER_HOME}/.local/share/claude" "${USER_HOME}/.local/bin/claude"
	else
		printf 'toolbox-seed-install: no /root seed for claude, installing over the network as %s\n' "${USER_NAME}"
		runuser -u "${USER_NAME}" -- env HOME="${USER_HOME}" sh -c 'curl -fsSL https://claude.ai/install.sh | bash'
	fi
fi

# Repair pass: fix any files from a pre-seed-script install that ended up
# root-owned (covers boxes carrying state from before this script existed).
# Safe to run every time — no-ops once ownership is already correct.
find "${USER_HOME}/.codex" "${USER_HOME}/.codex-spark" "${USER_HOME}/.local/share/claude" \
	! -user "${USER_NAME}" -exec chown "${USER_NAME}:${USER_NAME}" {} + 2> /dev/null || true
