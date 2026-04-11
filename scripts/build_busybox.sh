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

BUSYBOX_SRC="${BUILD_DIR}/busybox-${BUSYBOX_VERSION}"
cd "$BUSYBOX_SRC"

# scripts/config burada mevcut olmalı (BusyBox kaynak tarball ile gelir)
# Yoksa make defconfig çalıştır — scripts/config generate eder
echo "  -> .config oluşturuluyor..."
make defconfig KCONFIG_NOTIMESTAMP=1

# scripts/config varlığını doğrula
if [ ! -x "./scripts/config" ]; then
    echo "  [HATA] scripts/config bulunamadı!"
    ls -la scripts/ | head -20
    exit 1
fi

CFG="./scripts/config"

# Dinamik (glibc) bağlama — STATIC kapalı olmalı
$CFG --disable CONFIG_STATIC
$CFG --enable  CONFIG_INSTALL_NO_USR

# Init araçları
$CFG --enable CONFIG_INIT
$CFG --enable CONFIG_FEATURE_INIT_SYSLOG
$CFG --enable CONFIG_FEATURE_INIT_QUIET

# Faydalı appletler
$CFG --enable CONFIG_WGET
$CFG --enable CONFIG_FEATURE_WGET_HTTPS
$CFG --enable CONFIG_FEATURE_WGET_LONG_OPTIONS
$CFG --enable CONFIG_SH_IS_ASH
$CFG --disable CONFIG_BASH_IS_ASH    || true
$CFG --enable  CONFIG_FEATURE_EDITING
$CFG --enable  CONFIG_FEATURE_TAB_COMPLETION
$CFG --enable  CONFIG_FEATURE_REVERSE_SEARCH

# Yeni sorular için varsayılanları kullan (interaktif değil)
make olddefconfig

echo "  -> Derleniyor ($(nproc) çekirdek)..."
make -j"$(nproc)" ARCH=x86_64 \
    CC="gcc" \
    HOSTCC="gcc" \
    2>&1 | tail -20

echo "  -> RootFS dizinine kuruluyor: ${ROOTFS_DIR}"
sudo mkdir -p "$ROOTFS_DIR"
sudo make CONFIG_PREFIX="$ROOTFS_DIR" install

echo "==> BusyBox derlendi ve kuruldu ✓"
