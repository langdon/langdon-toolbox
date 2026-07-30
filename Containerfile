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

# Codex is intentionally NOT installed here (unlike Claude above). This RUN
# step executes as root at build time; /root is not host-shared and is
# permission-locked (dr-xr-x---), so anything installed to $HOME here is
# invisible/unreachable to the real runtime user. The standalone installer
# needs to land under the real (host-shared) ~/.codex, which only a step
# running as the actual user at container-entry time can do correctly —
# see distrobox.ini's init_hooks in this same directory tree.

RUN . /etc/os-release && echo "built on: $PRETTY_NAME"


