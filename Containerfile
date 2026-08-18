FROM registry.fedoraproject.org/fedora-toolbox:latest
RUN dnf copr enable -y atim/starship
ADD vscode.repo /etc/yum.repos.d/vscode.repo
#RUN dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo

RUN dnf install -y --setopt install_weak_deps=false \
	    bash-completion findutils iproute iputils inotify-tools unzip trash-cli wget curl tree \
            net-tools nmap openssl procps psmisc rsync man tig tmux tree vim htop xclip yt-dlp bind-utils \
            httpie ImageMagick pandoc sqlite age restic rclone \
            keychain git git-credential-libsecret ripgrep mosh \
            ansible-lint codespell desktop-file-utils gcc jq python3 poppler-utils \
            texlive-scheme-small texlive-needspace texlive-parskip texlive-microtype texlive-enumitem \
            kubernetes-client helm \
            bat duf howdoi starship plocate emacs-nox util-linux-script \
            code gh npm && \
    dnf remove -y wireplumber plocate && \
    dnf clean all

RUN dnf update -y && \
    dnf clean all

# this better be non-interactive
RUN curl -fsSL https://claude.ai/install.sh | bash

# Codex, same pattern as Claude above: install as root at build time into
# /root. This copy is NOT the one that ends up used — /root is not
# host-shared and is permission-locked (dr-xr-x---), so it's unreachable to
# the real runtime user. It exists purely as a build-time SEED: at container
# entry, distrobox.ini's init_hooks calls toolbox-seed-install.sh (copied in
# below), which copies this seed into the real (host-shared) user home —
# fast local `cp`, no network call — instead of re-running this same
# curl-based install fresh on every distrobox `assemble + enter`. Falls back
# to a live network install (as the real user, never as root) only if the
# seed is ever missing. See toolbox-seed-install.sh for the full mechanism,
# and distrobox.ini's init_hooks for where it's invoked.
RUN CODEX_NON_INTERACTIVE=true bash -c 'curl -fsSL https://chatgpt.com/codex/install.sh | sh'

# Seed-install script (see comment above) — copied in and made executable so
# distrobox.ini's init_hooks can call it by path.
COPY toolbox-seed-install.sh /usr/local/libexec/toolbox-seed-install.sh
RUN chmod +x /usr/local/libexec/toolbox-seed-install.sh

# Bitwarden Secrets Manager CLI (bws) — for scoped, revocable secret access
# (bws run -- <cmd>, never bws secret get) instead of plaintext tokens in
# config files. Version pinned; bump manually when needed rather than
# always pulling latest, since this is a security-sensitive binary.
RUN set -eux; \
    BWS_VERSION=2.1.0; \
    curl -fsSL -o /tmp/bws.zip "https://github.com/bitwarden/sdk-sm/releases/download/bws-v${BWS_VERSION}/bws-x86_64-unknown-linux-gnu-${BWS_VERSION}.zip"; \
    unzip -o /tmp/bws.zip -d /tmp; \
    install -m 0755 /tmp/bws /usr/local/bin/bws; \
    rm -f /tmp/bws.zip /tmp/bws; \
    bws --version

RUN . /etc/os-release && echo "built on: $PRETTY_NAME"


