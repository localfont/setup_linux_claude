#!/usr/bin/env bash
# ============================================================
# build_busybox.sh — BusyBox AMD64 glibc derlemesi
# ============================================================
set -euo pipefail

BUSYBOX_VERSION="${BUSYBOX_VERSION:-1.36.1}"
SRC_DIR="/tmp/busybox-src"
BUILD_DIR="/tmp/busybox-build"
ROOTFS_DIR="${ROOTFS_DIR:-/tmp/rootfs}"
TARBALL="busybox-${BUSYBOX_VERSION}.tar.bz2"
URL="https://busybox.net/downloads/${TARBALL}"

echo "==> BusyBox ${BUSYBOX_VERSION} derleniyor (AMD64, glibc)..."

# Kaynak indir
mkdir -p "$SRC_DIR"
if [ ! -f "${SRC_DIR}/${TARBALL}" ]; then
    echo "  -> Kaynak indiriliyor: $URL"
    wget -q --show-progress -O "${SRC_DIR}/${TARBALL}" "$URL"
fi

# Kaynak çıkar
mkdir -p "$BUILD_DIR"
if [ ! -d "${BUILD_DIR}/busybox-${BUSYBOX_VERSION}" ]; then
    echo "  -> Kaynak arşivden çıkarılıyor..."
    tar -xf "${SRC_DIR}/${TARBALL}" -C "$BUILD_DIR"
fi

cd "${BUILD_DIR}/busybox-${BUSYBOX_VERSION}"

# Defconfig + glibc için ayarla
echo "  -> .config oluşturuluyor..."
make defconfig

# Dinamik (glibc) bağlama — STATIC kapalı olmalı
scripts/config --disable CONFIG_STATIC
scripts/config --enable CONFIG_INSTALL_NO_USR

# İnit araçları — BusyBox kendi initi kullanacak ama OpenRC/sysvinit kurulunca override edilecek
scripts/config --enable CONFIG_INIT
scripts/config --enable CONFIG_FEATURE_INIT_SYSLOG
scripts/config --enable CONFIG_FEATURE_INIT_QUIET

# Faydalı appletler
scripts/config --enable CONFIG_WGET
scripts/config --enable CONFIG_FEATURE_WGET_HTTPS
scripts/config --enable CONFIG_FEATURE_WGET_LONG_OPTIONS
scripts/config --enable CONFIG_CURL  || true   # BusyBox curl desteği sınırlı, ayrıca kurulacak
scripts/config --enable CONFIG_SH_IS_ASH
scripts/config --enable CONFIG_BASH_IS_NONE
scripts/config --enable CONFIG_FEATURE_EDITING
scripts/config --enable CONFIG_FEATURE_TAB_COMPLETION
scripts/config --enable CONFIG_FEATURE_REVERSE_SEARCH

# make oldconfig ile doğrula
yes "" | make oldconfig

echo "  -> Derleniyor ($(nproc) çekirdek)..."
make -j"$(nproc)" ARCH=x86_64 \
    CC="gcc" \
    HOSTCC="gcc" \
    2>&1 | tail -20

echo "  -> RootFS dizinine kuruluyor: ${ROOTFS_DIR}"
sudo mkdir -p "$ROOTFS_DIR"
sudo make CONFIG_PREFIX="$ROOTFS_DIR" install

echo "==> BusyBox derlendi ve kuruldu ✓"
