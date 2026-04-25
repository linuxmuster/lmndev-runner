#!/bin/bash
#
# Build script for linuxmuster-linbo7
#
# The Linbo build is very resource-intensive (kernel, drivers, Busybox).
# ccache is activated automatically via common.sh.
# MAKEFLAGS can be set for parallel kernel builds.
#
# thomas@linuxmuster.net

source /opt/lmndev/build/common.sh

# Set parallel build jobs based on available CPUs
CPUS="$(nproc 2>/dev/null || echo 4)"
export MAKEFLAGS="-j${CPUS}"
export DEB_BUILD_OPTIONS="parallel=${CPUS}"

build_package
