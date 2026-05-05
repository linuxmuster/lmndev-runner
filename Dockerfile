# lmndev-runner
# Dockerfile für die linuxmuster.net Paket-Build-Umgebung
#
# thomas@linuxmuster.net
# 20260504

ARG UBUNTU_VERSION=26.04
FROM ubuntu:${UBUNTU_VERSION}

ARG DEFAULT_SHELL=bash
ARG EXTRA_PACKAGES="openssh-client iputils-ping net-tools wget bash bash-completion zsh \
    zsh-autosuggestions zsh-syntax-highlighting ccache distcc curl dpkg-dev debdelta \
    sudo vim git linux-image-generic linux-headers-generic r8125-dkms r8168-dkms zstd \
    opentracker pv kexec-tools chntpw"
ARG MY_USER=build
ARG MY_UID=1000
ARG MY_GID=1000

ENV DEFAULT_SHELL=${DEFAULT_SHELL}
ENV MY_USER=${MY_USER}
ENV MY_UID=${MY_UID}
ENV MY_GID=${MY_GID}

# Vorbereitete Dateien aus collect-deps.sh
COPY deps.txt linuxmuster-common.deb /tmp/

# Enable deb-src entries (required for apt-get source / dpkg-source)
RUN if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then \
        sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources; \
    fi

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get \
        -o "Dpkg::Options::=--force-confold" -y dist-upgrade

# Basis-Tools (immer installiert)
RUN DEBIAN_FRONTEND=noninteractive apt-get \
        -o "Dpkg::Options::=--force-confold" -y install \
    bash bash-completion ccache curl debhelper dpkg-dev fakeroot gdebi-core \
    gcc git gnupg gpg sudo tzdata wget

# Schnellsten Ubuntu-Mirror ermitteln und Paketlisten aktualisieren
RUN BEST=$( \
        { curl -sS --max-time 10 "https://mirrors.ubuntu.com/mirrors.txt" 2>/dev/null || true; } | \
        head -10 | \
        while IFS= read -r m; do \
            t=$(curl -o /dev/null -s -w '%{time_connect}' --max-time 1 "${m}" 2>/dev/null) && \
            printf '%s %s\n' "$t" "$m" || true; \
        done | sort -n | awk 'NR==1{print $2}') && \
    if [ -n "$BEST" ]; then \
        echo "Schnellster Mirror: $BEST"; \
        for f in /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list; do \
            [ -f "$f" ] && sed -Ei "s|http://archive.ubuntu.com/ubuntu/?|${BEST%/}|g" "$f" || true; \
        done && \
        apt-get update -q; \
    fi

# Projekt-Build-Abhängigkeiten: nicht verfügbare Pakete nach /tmp/fails.txt schreiben,
# verfügbare in einem Schritt bulk-installieren
RUN apt-get install -sy $(cat /tmp/deps.txt) 2>&1 \
        | grep -E "^E: (Unable to locate package|Package '.*' has no installation candidate)" \
        | sed -E "s/^E: Unable to locate package //; \
                  s/^E: Package '(.*)' has no installation candidate.*/\1/" \
        > /tmp/fails.txt || true; \
    if [ -s /tmp/fails.txt ]; then \
        echo "--- Nicht verfügbare Pakete (übersprungen):"; \
        cat /tmp/fails.txt; \
    fi; \
    PKGS=$(grep -vxFf /tmp/fails.txt /tmp/deps.txt | tr '\n' ' '); \
    DEBIAN_FRONTEND=noninteractive apt-get \
        -o "Dpkg::Options::=--force-confold" -y install $PKGS

# linuxmuster-common aus dem neuesten GitHub Release
RUN DEBIAN_FRONTEND=noninteractive gdebi -n /tmp/linuxmuster-common.deb

# Alle unterstützten Shells installieren (Auswahl zur Laufzeit per DEFAULT_SHELL)
RUN DEBIAN_FRONTEND=noninteractive apt-get \
        -o "Dpkg::Options::=--force-confold" -y install \
    bash zsh fish busybox && \
    ln -sf /bin/busybox /bin/ash

# Optionale lokale Pakete
RUN if [ -n "${EXTRA_PACKAGES}" ]; then \
        DEBIAN_FRONTEND=noninteractive apt-get \
            -o "Dpkg::Options::=--force-confold" -y install ${EXTRA_PACKAGES}; \
    fi

RUN apt-get clean && apt-get -y autoremove && \
    rm -rf /var/lib/apt/lists/* /tmp/deps.txt /tmp/fails.txt /tmp/linuxmuster-common.deb

# Build-User anlegen
RUN userdel -f ubuntu 2>/dev/null || true && \
    groupdel -f ubuntu 2>/dev/null || true
RUN groupadd -g ${MY_GID} ${MY_USER}
RUN case "${DEFAULT_SHELL}" in \
        ash)  SHELL_BIN="/bin/ash" ;; \
        fish) SHELL_BIN="/usr/bin/fish" ;; \
        *)    SHELL_BIN="/bin/${DEFAULT_SHELL}" ;; \
    esac && \
    useradd -s "${SHELL_BIN}" \
        -c 'lmndev build user' \
        -d /home/${MY_USER} -m \
        -u ${MY_UID} -g ${MY_USER} -G sudo ${MY_USER}
RUN echo "${MY_USER} ALL=NOPASSWD: ALL" > /etc/sudoers.d/${MY_USER} && \
    chmod 400 /etc/sudoers.d/${MY_USER}

# Pro-Projekt-Buildskripte in den Container kopieren
COPY build/ /opt/lmndev/build/
RUN chmod +x /opt/lmndev/build/*.sh

ENV PATH="/opt/lmndev/build:${PATH}"

CMD ["/bin/sh", "-c", "exec /bin/${DEFAULT_SHELL:-bash}"]
