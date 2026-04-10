#!/usr/bin/env bash
# ============================================================
# install_pkgs_xbps.sh — wget, curl, nano, sudo xbps ile kur
# ============================================================
set -euo pipefail

ROOTFS_DIR="${ROOTFS_DIR:-/tmp/rootfs}"
VOID_MIRROR="https://repo-default.voidlinux.org/current"

# xbps-install binary belirle
if [ -f "$ROOTFS_DIR/usr/bin/xbps-install" ]; then
    XBPS_INSTALL="sudo $ROOTFS_DIR/usr/bin/xbps-install"
else
    XBPS_INSTALL=$(find /tmp/xbps-static -name "xbps-install.static" | head -1)
    XBPS_INSTALL="sudo $XBPS_INSTALL"
fi

XBPS_OPTS="-r $ROOTFS_DIR --repository=$VOID_MIRROR -y"

echo "==> Temel paketler xbps ile kuruluyor..."

PACKAGES=(
    # Temel araçlar
    wget
    curl
    nano
    sudo
    # Kabuk
    bash
    # Sistem araçları
    coreutils
    util-linux
    procps-ng
    grep
    sed
    gawk
    findutils
    diffutils
    tar
    gzip
    xz
    bzip2
    zstd
    # Ağ araçları
    iproute2
    iputils
    # Geliştirici araçları (opsiyonel ama kullanışlı)
    less
    which
    file
    man-db
)

echo "  -> Şu paketler kuruluyor: ${PACKAGES[*]}"

$XBPS_INSTALL $XBPS_OPTS "${PACKAGES[@]}" 2>&1 || {
    echo "  [UYARI] Toplu kurulum başarısız, tek tek deneniyor..."
    for pkg in "${PACKAGES[@]}"; do
        echo "     -> $pkg kuruluyor..."
        $XBPS_INSTALL $XBPS_OPTS "$pkg" 2>&1 || echo "     [ATLA] $pkg kurulamadı"
    done
}

# sudo konfigürasyonu
echo "  -> sudo yapılandırılıyor..."
sudo mkdir -p "$ROOTFS_DIR/etc/sudoers.d"
sudo tee "$ROOTFS_DIR/etc/sudoers" > /dev/null <<'EOF'
# sudoers dosyası
Defaults env_reset
Defaults mail_badpass
Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

root ALL=(ALL:ALL) ALL
%wheel ALL=(ALL:ALL) ALL

# İzin ver: sudoers.d altındaki dosyalar
#includedir /etc/sudoers.d
EOF
sudo chmod 440 "$ROOTFS_DIR/etc/sudoers"

# nano konfigürasyonu
sudo tee "$ROOTFS_DIR/etc/nanorc" > /dev/null <<'EOF'
set smooth
set autoindent
set tabsize 4
set linenumbers
set mouse
include "/usr/share/nano/*.nanorc"
EOF

# curl konfigürasyonu
sudo mkdir -p "$ROOTFS_DIR/etc/ssl/certs"
# CA sertifikalarını kopyala
if [ -f "/etc/ssl/certs/ca-certificates.crt" ]; then
    sudo cp "/etc/ssl/certs/ca-certificates.crt" \
        "$ROOTFS_DIR/etc/ssl/certs/ca-certificates.crt"
fi

echo "  -> Kurulu paketler:"
ls "$ROOTFS_DIR/usr/bin/" | grep -E "wget|curl|nano|sudo|bash" || true

echo "==> Temel paketler kuruldu ✓"
