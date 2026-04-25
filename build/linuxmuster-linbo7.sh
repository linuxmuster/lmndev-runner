#!/bin/bash
#
# Build-Skript für linuxmuster-linbo7
#
# Der Linbo-Build ist sehr ressourcenintensiv (Kernel, Treiber, Busybox).
# ccache wird automatisch über common.sh aktiviert.
# Für parallele Kernel-Builds kann MAKEFLAGS gesetzt werden.
#
# thomas@linuxmuster.net

source /opt/lmndev/build/common.sh

# Parallele Build-Jobs nach verfügbaren CPUs setzen
CPUS="$(nproc 2>/dev/null || echo 4)"
export MAKEFLAGS="-j${CPUS}"
export DEB_BUILD_OPTIONS="parallel=${CPUS}"

build_package
