#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
ROOT="$(cd $DIR/../ && pwd)"
SUDO=""

# NOTE: this is used in a docker build, so do not run any scripts here.

# Use sudo if not root
if [[ ! $(id -u) -eq 0 ]]; then
  if [[ -z $(which sudo) ]]; then
    echo "Please install sudo or run as root"
    exit 1
  fi
  SUDO="sudo"
fi

# Ubuntu 24.04 renamed some runtime libraries (64-bit time_t transition)
LIBGLIB="libglib2.0-0"
LIBPNG="libpng16-16"
if [ -f "/etc/os-release" ] && grep -q "VERSION_CODENAME=noble" /etc/os-release; then
  LIBGLIB="libglib2.0-0t64"
  LIBPNG="libpng16-16t64"
fi

# Install packages present in all supported versions of Ubuntu
function install_ubuntu_common_requirements() {
  $SUDO apt-get update
  $SUDO apt-get install -y --no-install-recommends \
    autoconf \
    build-essential \
    ca-certificates \
    casync \
    clang \
    cmake \
    make \
    cppcheck \
    libtool \
    gcc-arm-none-eabi \
    bzip2 \
    liblzma-dev \
    libarchive-dev \
    libbz2-dev \
    capnproto \
    libcapnp-dev \
    curl \
    libcurl4-openssl-dev \
    git \
    git-lfs \
    ffmpeg \
    libavformat-dev \
    libavcodec-dev \
    libavdevice-dev \
    libavutil-dev \
    libavfilter-dev \
    libeigen3-dev \
    libffi-dev \
    libglew-dev \
    libgles2-mesa-dev \
    libglfw3-dev \
    $LIBGLIB \
    libomp-dev \
    libopencv-dev \
    $LIBPNG \
    libportaudio2 \
    libssl-dev \
    libsqlite3-dev \
    libusb-1.0-0-dev \
    libzmq3-dev \
    libsystemd-dev \
    locales \
    opencl-headers \
    ocl-icd-libopencl1 \
    ocl-icd-opencl-dev \
    clinfo \
    qml-module-qtquick2 \
    qtmultimedia5-dev \
    qtlocation5-dev \
    qtpositioning5-dev \
    qttools5-dev-tools \
    libqt5sql5-sqlite \
    libqt5svg5-dev \
    libqt5charts5-dev \
    libqt5x11extras5-dev \
    libreadline-dev \
    libdw1 \
    valgrind
}

# Install Ubuntu 22.04 LTS packages
function install_ubuntu_lts_latest_requirements() {
  install_ubuntu_common_requirements

  $SUDO apt-get install -y --no-install-recommends \
    g++-12 \
    qtbase5-dev \
    qtchooser \
    qt5-qmake \
    qtbase5-dev-tools \
    python3-dev
}

# Install Ubuntu 20.04 packages
function install_ubuntu_focal_requirements() {
  install_ubuntu_common_requirements

  $SUDO apt-get install -y --no-install-recommends \
    libavresample-dev \
    qt5-default \
    python-dev
}

# Record which apt packages (including dependencies) this script newly installs,
# so tools/ubuntu_uninstall.sh can remove exactly those and nothing else
APT_LOG="$HOME/.openpilot_apt_installed.txt"
PKGS_BEFORE=$(mktemp)
dpkg-query -W -f='${db:Status-Status} ${binary:Package}\n' | awk '$1=="installed"{print $2}' | sort > "$PKGS_BEFORE"

# Detect OS using /etc/os-release file
if [ -f "/etc/os-release" ]; then
  source /etc/os-release
  case "$VERSION_CODENAME" in
    "jammy")
      install_ubuntu_lts_latest_requirements
      ;;
    "noble")
      install_ubuntu_lts_latest_requirements
      ;;
    "kinetic")
      install_ubuntu_lts_latest_requirements
      ;;
    "focal")
      install_ubuntu_focal_requirements
      ;;
    *)
      echo "$ID $VERSION_ID is unsupported. This setup script is written for Ubuntu 20.04."
      read -p "Would you like to attempt installation anyway? " -n 1 -r
      echo ""
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
      fi
      if [ "$UBUNTU_CODENAME" = "jammy" ] || [ "$UBUNTU_CODENAME" = "kinetic" ]; then
        install_ubuntu_lts_latest_requirements
      else
        install_ubuntu_focal_requirements
      fi
  esac
else
  echo "No /etc/os-release in the system"
  exit 1
fi

PKGS_AFTER=$(mktemp)
dpkg-query -W -f='${db:Status-Status} ${binary:Package}\n' | awk '$1=="installed"{print $2}' | sort > "$PKGS_AFTER"
touch "$APT_LOG"
comm -13 "$PKGS_BEFORE" "$PKGS_AFTER" | cat - "$APT_LOG" | sort -u > "$APT_LOG.tmp" && mv "$APT_LOG.tmp" "$APT_LOG"
rm -f "$PKGS_BEFORE" "$PKGS_AFTER"
echo "newly installed apt packages recorded in $APT_LOG ($(wc -l < "$APT_LOG") total)"

# install python dependencies
$ROOT/update_requirements.sh

# add openpilot_env.sh to the rc file of the user's login shell (bash or zsh)
RC_FILE="$HOME/.$(basename ${SHELL:-bash})rc"
if ! grep -qs "tools/openpilot_env.sh" "$RC_FILE"; then
  printf "\nsource %s/tools/openpilot_env.sh\n" "$ROOT" >> "$RC_FILE"
  echo "added openpilot_env to $RC_FILE"
fi

echo
echo "----   OPENPILOT SETUP DONE   ----"
echo "Open a new shell or configure your active shell env by running:"
echo "source $RC_FILE"
