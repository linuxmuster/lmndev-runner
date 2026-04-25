# lmndev-runner
# Dockerfile für die linuxmuster.net Paket-Build-Umgebung
#
# thomas@linuxmuster.net
# 20260425

ARG UBUNTU_VERSION=26.04
FROM ubuntu:${UBUNTU_VERSION}

ARG DEFAULT_SHELL=bash
ARG EXTRA_PACKAGES=""
ARG MY_USER=build
ARG MY_UID=1000
ARG MY_GID=1001

ENV DEFAULT_SHELL=${DEFAULT_SHELL}
ENV MY_USER=${MY_USER}
ENV MY_UID=${MY_UID}
ENV MY_GID=${MY_GID}

# Vorbereitete Dateien aus collect-deps.sh
COPY deps.txt linuxmuster-common.deb /tmp/

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get \
        -o "Dpkg::Options::=--force-confold" -y dist-upgrade

# Basis-Tools (immer installiert)
RUN DEBIAN_FRONTEND=noninteractive apt-get \
        -o "Dpkg::Options::=--force-confold" -y install \
    bash bash-completion ccache curl debhelper dpkg-dev fakeroot gdebi-core \
    git gnupg gpg sudo tzdata wget

# Projekt-Build-Abhängigkeiten (aus deps.txt, von collect-deps.sh generiert)
RUN DEBIAN_FRONTEND=noninteractive apt-get \
        -o "Dpkg::Options::=--force-confold" -y install \
    $(cat /tmp/deps.txt) || true

# linuxmuster-common aus dem neuesten GitHub Release
RUN DEBIAN_FRONTEND=noninteractive gdebi -n /tmp/linuxmuster-common.deb

# Konfigurierte Shell installieren
RUN case "${DEFAULT_SHELL}" in \
        ash) \
            DEBIAN_FRONTEND=noninteractive apt-get \
                -o "Dpkg::Options::=--force-confold" -y install busybox && \
            ln -sf /bin/busybox /bin/ash \
            ;; \
        fish) \
            DEBIAN_FRONTEND=noninteractive apt-get \
                -o "Dpkg::Options::=--force-confold" -y install fish \
            ;; \
        *) \
            DEBIAN_FRONTEND=noninteractive apt-get \
                -o "Dpkg::Options::=--force-confold" -y install "${DEFAULT_SHELL}" \
            ;; \
    esac

# Optionale lokale Pakete
RUN if [ -n "${EXTRA_PACKAGES}" ]; then \
        DEBIAN_FRONTEND=noninteractive apt-get \
            -o "Dpkg::Options::=--force-confold" -y install ${EXTRA_PACKAGES}; \
    fi

RUN apt-get clean && apt-get -y autoremove && \
    rm -rf /var/lib/apt/lists/* /tmp/deps.txt /tmp/linuxmuster-common.deb

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
        -d /home/${MY_USER} -M \
        -u ${MY_UID} -g ${MY_USER} -G sudo ${MY_USER}
RUN echo "${MY_USER} ALL=NOPASSWD: ALL" > /etc/sudoers.d/${MY_USER} && \
    chmod 400 /etc/sudoers.d/${MY_USER}

# Pro-Projekt-Buildskripte in den Container kopieren
COPY build/ /opt/lmndev/build/
RUN chmod +x /opt/lmndev/build/*.sh

ENV PATH="/opt/lmndev/build:${PATH}"

CMD ["/bin/sh", "-c", "exec /bin/${DEFAULT_SHELL:-bash}"]
