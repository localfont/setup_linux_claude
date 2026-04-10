#!/usr/bin/env bash
# ============================================================
# install_pacman.sh — pacman paket yöneticisini rootfs'e kur
# ============================================================
set -euo pipefail

ROOTFS_DIR="${ROOTFS_DIR:-/tmp/rootfs}"
ARCH_MIRROR="https://geo.mirror.pkgbuild.com"
PACMAN_VERSION="6.1.0"
PACSTRAP_DB="$ROOTFS_DIR/var/lib/pacman"

echo "==> pacman ${PACMAN_VERSION} ortamı hazırlanıyor..."

# Arch Linux bootstrap tarball ile pacman ortamını kur
BOOTSTRAP_URL="https://geo.mirror.pkgbuild.com/iso/latest/archlinux-bootstrap-x86_64.tar.zst"
BOOTSTRAP_TMP="/tmp/arch-bootstrap"

echo "  -> Arch Linux bootstrap indiriliyor..."
mkdir -p "$BOOTSTRAP_TMP"
wget -q --show-progress -O "$BOOTSTRAP_TMP/bootstrap.tar.zst" "$BOOTSTRAP_URL"

echo "  -> Bootstrap açılıyor..."
sudo apt-get install -y zstd 2>/dev/null || true
sudo tar --zstd -xf "$BOOTSTRAP_TMP/bootstrap.tar.zst" \
    -C "$BOOTSTRAP_TMP" 2>/dev/null || \
sudo tar -I zstd -xf "$BOOTSTRAP_TMP/bootstrap.tar.zst" \
    -C "$BOOTSTRAP_TMP"

BOOTSTRAP_ROOT=$(find "$BOOTSTRAP_TMP" -maxdepth 2 -name "pacman" -path "*/usr/bin/*" \
    | sed 's|/usr/bin/pacman||' | head -1)

echo "  -> Bootstrap root: $BOOTSTRAP_ROOT"

# pacman binary + kütüphaneleri rootfs'e kopyala
echo "  -> pacman binary ve kütüphaneleri kopyalanıyor..."
for d in usr/bin usr/lib usr/share/pacman etc/pacman.d; do
    sudo mkdir -p "$ROOTFS_DIR/$d"
done

# pacman ve gerekli binary'leri kopyala
PACMAN_BINS=(pacman pacman-key makepkg vercmp)
for bin in "${PACMAN_BINS[@]}"; do
    SRC="${BOOTSTRAP_ROOT}/usr/bin/$bin"
    [ -f "$SRC" ] && sudo cp -a "$SRC" "$ROOTFS_DIR/usr/bin/" || true
done

# pacman kütüphaneleri
sudo cp -a "${BOOTSTRAP_ROOT}/usr/lib/libalpm"* "$ROOTFS_DIR/usr/lib/" 2>/dev/null || true
sudo cp -a "${BOOTSTRAP_ROOT}/usr/lib/libarchive"* "$ROOTFS_DIR/usr/lib/" 2>/dev/null || true
sudo cp -a "${BOOTSTRAP_ROOT}/usr/lib/libcurl"* "$ROOTFS_DIR/usr/lib/" 2>/dev/null || true
sudo cp -a "${BOOTSTRAP_ROOT}/usr/lib/libgpgme"* "$ROOTFS_DIR/usr/lib/" 2>/dev/null || true
sudo cp -a "${BOOTSTRAP_ROOT}/usr/lib/libassuan"* "$ROOTFS_DIR/usr/lib/" 2>/dev/null || true

# pacman konfigürasyonu
echo "  -> pacman.conf yazılıyor..."
sudo mkdir -p "$ROOTFS_DIR/etc"
sudo tee "$ROOTFS_DIR/etc/pacman.conf" > /dev/null <<EOF
[options]
HoldPkg      = pacman glibc
Architecture = x86_64
Color
ParallelDownloads = 5
SigLevel    = Never

[core]
Server = ${ARCH_MIRROR}/\$repo/os/\$arch
Server = https://mirror.rackspace.com/archlinux/\$repo/os/\$arch

[extra]
Server = ${ARCH_MIRROR}/\$repo/os/\$arch
Server = https://mirror.rackspace.com/archlinux/\$repo/os/\$arch

[community]
Server = ${ARCH_MIRROR}/\$repo/os/\$arch
EOF

# pacman veritabanı dizini
sudo mkdir -p "$PACSTRAP_DB/sync" "$PACSTRAP_DB/local"

# mount proc/sys/dev (chroot için)
sudo mount --bind /proc "$ROOTFS_DIR/proc" 2>/dev/null || true
sudo mount --bind /sys  "$ROOTFS_DIR/sys"  2>/dev/null || true
sudo mount --bind /dev  "$ROOTFS_DIR/dev"  2>/dev/null || true

# pacman keyring başlat
echo "  -> pacman keyring başlatılıyor..."
sudo chroot "$ROOTFS_DIR" /bin/sh -c \
    "pacman-key --init && pacman-key --populate archlinux" 2>/dev/null || \
    echo "  [UYARI] keyring başlatılamadı, SigLevel=Never ile devam ediliyor"

# Veritabanını senkronize et
echo "  -> pacman veritabanı senkronize ediliyor..."
sudo chroot "$ROOTFS_DIR" /usr/bin/pacman -Sy --noconfirm 2>&1 | tail -10 || true

echo "==> pacman kuruldu ✓"
