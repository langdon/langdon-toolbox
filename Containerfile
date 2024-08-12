FROM registry.fedoraproject.org/fedora-toolbox:latest
RUN dnf copr enable -y atim/starship
ADD vscode.repo /etc/yum.repos.d/vscode.repo 
RUN dnf install -y bash-completion findutils iproute iputils inotify-tools unzip trash-cli wget curl tree \
            net-tools nmap openssl procps psmisc rsync man tig tmux tree vim htop xclip yt-dlp \
            httpie ImageMagick pandoc \
            git git-credential-libsecret hub \
            ansible-lint codespell desktop-file-utils gcc jq python3 \
            kubernetes-client helm \
            bat duf howdoi starship mlocate \
	    code && \
    dnf clean all

