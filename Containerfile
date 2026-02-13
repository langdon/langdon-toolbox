FROM registry.fedoraproject.org/fedora-toolbox:latest
RUN dnf copr enable -y atim/starship
ADD vscode.repo /etc/yum.repos.d/vscode.repo
#RUN dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo

RUN dnf install -y --setopt install_weak_deps=false \
	    bash-completion findutils iproute iputils inotify-tools unzip trash-cli wget curl tree \
            net-tools nmap openssl procps psmisc rsync man tig tmux tree vim htop xclip yt-dlp bind-utils \
            httpie ImageMagick pandoc sqlite \
            git git-credential-libsecret \
            ansible-lint codespell desktop-file-utils gcc jq python3 \
            kubernetes-client helm \
            bat duf howdoi starship plocate emacs-nox util-linux-script \
            code gh npm && \
    dnf remove -y wireplumber plocate && \
    dnf clean all

RUN dnf update -y && \
    dnf clean all

# this better be non-interactive
RUN curl -fsSL https://claude.ai/install.sh | bash

RUN npm install -g @openai/codex && npm cache clean --force

RUN . /etc/os-release && echo "built on: $PRETTY_NAME"


