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
#   /usr/local/libexec/toolbox-seed-install.sh "$container_user_name" "$container_user_home" codex [codex-profile ...]
# Profile names become both the launcher name and its dot-directory beneath
# the user's home. With no profiles specified, only the default `codex`
# profile is installed.
#
# Idempotent — package copies and installs are guarded, while the tiny launcher
# wrappers are safely refreshed on every container start.

set -eu

USER_NAME="${1:?missing container user name}"
USER_HOME="${2:?missing container user home}"
shift 2

[ "$#" -gt 0 ] || set -- codex

# codex: same package payload for all profiles, seeded once at build time
# under /root/.codex, copied into whichever real profile home
# doesn't have it yet.
seed_or_fetch_codex() {
	target_home="$1"

	[ -x "${target_home}/packages/standalone/current/bin/codex" ] && return 0

	if [ -d /root/.codex/packages/standalone ]; then
		printf 'toolbox-seed-install: seeding codex into %s from /root copy\n' "${target_home}"
		mkdir -p "${target_home}"
		cp -a /root/.codex/packages "${target_home}/"
		chown -R "${USER_NAME}:${USER_NAME}" "${target_home}"
	else
		printf 'toolbox-seed-install: no /root seed for codex, installing over the network as %s\n' "${USER_NAME}"
		runuser -u "${USER_NAME}" -- env HOME="${USER_HOME}" CODEX_HOME="${target_home}" CODEX_NON_INTERACTIVE=true \
			sh -c 'curl -fsSL https://chatgpt.com/codex/install.sh | sh'
	fi
}

# Use a wrapper rather than a symlink so each command sets CODEX_HOME and
# invokes the standalone binary belonging to that same profile. This avoids
# whichever install last updated ~/.local/bin/codex determining all profiles.
install_codex_launcher() {
	command_name="$1"
	profile_home="$2"
	launcher="${USER_HOME}/.local/bin/${command_name}"

	mkdir -p "${USER_HOME}/.local/bin"
	# Remove an installer-created symlink before redirecting into this path;
	# otherwise the shell would follow it and overwrite the linked binary.
	rm -f "${launcher}"
	printf '%s\n' \
		'#!/bin/sh' \
		"CODEX_HOME=\"${profile_home}\" exec \"${profile_home}/packages/standalone/current/bin/codex\" \"\$@\"" \
		> "${launcher}"
	chmod 0755 "${launcher}"
	chown "${USER_NAME}:${USER_NAME}" "${launcher}"
}

for command_name in "$@"; do
	case "${command_name}" in
		''|*[!A-Za-z0-9._-]*)
			printf 'toolbox-seed-install: invalid codex profile name: %s\n' "${command_name}" >&2
			exit 2
			;;
	esac

	profile_home="${USER_HOME}/.${command_name}"
	seed_or_fetch_codex "${profile_home}"
	install_codex_launcher "${command_name}" "${profile_home}"

	# Repair files left root-owned by versions of this installer predating
	# the seed mechanism. This is a no-op once ownership is correct.
	find "${profile_home}" ! -user "${USER_NAME}" \
		-exec chown "${USER_NAME}:${USER_NAME}" {} + 2> /dev/null || true
done

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
find "${USER_HOME}/.local/share/claude" \
	! -user "${USER_NAME}" -exec chown "${USER_NAME}:${USER_NAME}" {} + 2> /dev/null || true
