#!/usr/bin/env bash
# ============================================================
# install_pkgs_pacman.sh — wget, curl, nano, sudo pacman ile kur
# ============================================================
set -euo pipefail

ROOTFS_DIR="${ROOTFS_DIR:-/tmp/rootfs}"

# proc/sys/dev zaten mount edilmiş olmalı (install_pacman.sh'dan)
for mnt in proc sys dev; do
    mountpoint -q "$ROOTFS_DIR/$mnt" 2>/dev/null || \
        sudo mount --bind "/$mnt" "$ROOTFS_DIR/$mnt" 2>/dev/null || true
done

echo "==> Temel paketler pacman ile kuruluyor..."

PACKAGES=(
    wget
    curl
    nano
    sudo
    bash
    coreutils
    util-linux
    procps-ng
    iproute2
    iputils
    less
    which
    file
    tar
    gzip
    xz
    bzip2
    zstd
    grep
    sed
    gawk
    findutils
    ca-certificates
)

echo "  -> Şu paketler kuruluyor: ${PACKAGES[*]}"

sudo chroot "$ROOTFS_DIR" /usr/bin/pacman \
    -Sy --noconfirm --needed \
    "${PACKAGES[@]}" 2>&1 | tail -30 || {
    echo "  [UYARI] Toplu kurulum başarısız, tek tek deneniyor..."
    for pkg in "${PACKAGES[@]}"; do
        echo "     -> $pkg kuruluyor..."
        sudo chroot "$ROOTFS_DIR" /usr/bin/pacman \
            -Sy --noconfirm --needed "$pkg" 2>&1 || \
            echo "     [ATLA] $pkg kurulamadı"
    done
}

# sudo konfigürasyonu
echo "  -> sudo yapılandırılıyor..."
sudo mkdir -p "$ROOTFS_DIR/etc/sudoers.d"
sudo tee "$ROOTFS_DIR/etc/sudoers" > /dev/null <<'EOF'
Defaults env_reset
Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

root ALL=(ALL:ALL) ALL
%wheel ALL=(ALL:ALL) ALL
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

echo "==> Temel paketler kuruldu ✓"
