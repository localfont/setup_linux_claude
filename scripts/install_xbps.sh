#!/usr/bin/env bash
# ============================================================
# install_xbps.sh — xbps paket yöneticisini rootfs'e kur
# ============================================================
set -euo pipefail

ROOTFS_DIR="${ROOTFS_DIR:-/tmp/rootfs}"
XBPS_VERSION="0.59.2"
XBPS_ARCH="x86_64"
XBPS_URL="https://github.com/void-linux/xbps/releases/download/${XBPS_VERSION}/xbps-static-${XBPS_VERSION}.${XBPS_ARCH}-musl.tar.xz"
VOID_MIRROR="https://repo-default.voidlinux.org/current"

echo "==> xbps ${XBPS_VERSION} kuruluyor..."

# xbps-static indir (bootstrap için musl statik binary)
XBPS_TMP="/tmp/xbps-static"
mkdir -p "$XBPS_TMP"
wget -q --show-progress -O "$XBPS_TMP/xbps-static.tar.xz" "$XBPS_URL"
tar -xf "$XBPS_TMP/xbps-static.tar.xz" -C "$XBPS_TMP"

# Bootstrap binary
XBPS_BIN=$(find "$XBPS_TMP" -name "xbps-install.static" | head -1)
XBPS_QUERY=$(find "$XBPS_TMP" -name "xbps-query.static"  | head -1)
XBPS_RQUERY=$(find "$XBPS_TMP" -name "xbps-rindex.static" | head -1)

[ -z "$XBPS_BIN" ] && { echo "HATA: xbps-install.static bulunamadı!"; exit 1; }

echo "  -> xbps-install binary: $XBPS_BIN"

# Rootfs içine xbps konfigürasyonu
sudo mkdir -p "$ROOTFS_DIR/etc/xbps.d"
sudo tee "$ROOTFS_DIR/etc/xbps.d/00-repository-main.conf" > /dev/null <<EOF
repository=${VOID_MIRROR}
EOF

sudo tee "$ROOTFS_DIR/etc/xbps.d/01-repository-nonfree.conf" > /dev/null <<EOF
repository=${VOID_MIRROR}/nonfree
EOF

# xbps-install ile rootfs içine xbps'i glibc native olarak kur
echo "  -> xbps glibc paketi rootfs'e kuruluyor..."
sudo "$XBPS_BIN" \
    -r "$ROOTFS_DIR" \
    --repository="$VOID_MIRROR" \
    -y \
    xbps

# xbps binary'leri /usr/bin'de olduğunu doğrula
echo "  -> xbps kurulum doğrulanıyor..."
ls -la "$ROOTFS_DIR/usr/bin/xbps-install" 2>/dev/null \
    || echo "  [UYARI] xbps-install /usr/bin içinde yok, statik kopyalanıyor..."

# Fallback: statik xbps-install'ı kopyala
if [ ! -f "$ROOTFS_DIR/usr/bin/xbps-install" ]; then
    sudo cp "$XBPS_BIN"    "$ROOTFS_DIR/usr/bin/xbps-install"
    sudo cp "$XBPS_QUERY"  "$ROOTFS_DIR/usr/bin/xbps-query"   2>/dev/null || true
    sudo chmod +x "$ROOTFS_DIR/usr/bin/xbps-install"
    sudo chmod +x "$ROOTFS_DIR/usr/bin/xbps-query"
fi

# Güncelle
echo "  -> xbps paket listesi güncelleniyor..."
sudo "$XBPS_BIN" \
    -r "$ROOTFS_DIR" \
    --repository="$VOID_MIRROR" \
    -Sy \
    xbps 2>&1 || true

echo "==> xbps kuruldu ✓"
