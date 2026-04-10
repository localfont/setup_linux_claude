#!/usr/bin/env bash
# ============================================================
# finalize_rootfs.sh — Son ayarlar, temizlik ve doğrulama
# ============================================================
set -euo pipefail

ROOTFS_DIR="${ROOTFS_DIR:-/tmp/rootfs}"

echo "==> RootFS sonlandırılıyor..."

# ---- /init sembolik linki (initramfs uyumluluğu) ----
if [ ! -f "$ROOTFS_DIR/init" ] && [ ! -L "$ROOTFS_DIR/init" ]; then
    INIT_BIN=""
    for p in /usr/sbin/init /sbin/init /bin/init; do
        [ -f "${ROOTFS_DIR}${p}" ] && { INIT_BIN="$p"; break; }
    done
    # BusyBox init fallback
    [ -z "$INIT_BIN" ] && INIT_BIN="/bin/busybox"
    sudo ln -sf "$INIT_BIN" "$ROOTFS_DIR/init"
fi

# ---- /sbin/init doğrula ----
if [ ! -f "$ROOTFS_DIR/sbin/init" ] && [ ! -L "$ROOTFS_DIR/sbin/init" ]; then
    echo "  [UYARI] /sbin/init bulunamadı, BusyBox init kullanılıyor..."
    sudo ln -sf /bin/busybox "$ROOTFS_DIR/sbin/init" 2>/dev/null || true
fi

# ---- ldconfig çalıştır ----
echo "  -> ldconfig çalıştırılıyor..."
if [ -f "$ROOTFS_DIR/sbin/ldconfig" ] || [ -f "$ROOTFS_DIR/usr/sbin/ldconfig" ]; then
    sudo chroot "$ROOTFS_DIR" ldconfig 2>/dev/null || true
else
    # Host ldconfig ile
    sudo ldconfig -r "$ROOTFS_DIR" 2>/dev/null || true
fi

# ---- umount (eğer mount edilmişse) ----
for mnt in proc sys dev; do
    mountpoint -q "$ROOTFS_DIR/$mnt" 2>/dev/null && \
        sudo umount -l "$ROOTFS_DIR/$mnt" 2>/dev/null || true
done

# ---- İzinleri düzelt ----
echo "  -> İzinler düzeltiliyor..."
sudo chmod 755  "$ROOTFS_DIR"
sudo chmod 1777 "$ROOTFS_DIR/tmp"
sudo chmod 700  "$ROOTFS_DIR/root"
sudo chmod 600  "$ROOTFS_DIR/etc/shadow" 2>/dev/null || true
sudo chmod 440  "$ROOTFS_DIR/etc/sudoers" 2>/dev/null || true

# init.d scriptlerini çalıştırılabilir yap
find "$ROOTFS_DIR/etc/init.d/" -type f 2>/dev/null | \
    xargs sudo chmod +x 2>/dev/null || true

# ---- Gereksiz dosyaları temizle ----
echo "  -> Önbellek temizleniyor..."
sudo rm -rf "$ROOTFS_DIR/var/cache/xbps"   2>/dev/null || true
sudo rm -rf "$ROOTFS_DIR/var/cache/pacman" 2>/dev/null || true
sudo rm -rf "$ROOTFS_DIR/tmp/"*            2>/dev/null || true

# ---- Doğrulama raporu ----
echo ""
echo "=========================================="
echo "  RootFS Doğrulama Raporu"
echo "=========================================="

check_file() {
    local label="$1"
    local path="$2"
    if [ -f "${ROOTFS_DIR}${path}" ] || [ -L "${ROOTFS_DIR}${path}" ]; then
        echo "  ✅  $label → ${path}"
    else
        echo "  ❌  $label → ${path} BULUNAMADI"
    fi
}

check_dir() {
    local label="$1"
    local path="$2"
    if [ -d "${ROOTFS_DIR}${path}" ]; then
        echo "  ✅  $label → ${path}"
    else
        echo "  ❌  $label → ${path} BULUNAMADI"
    fi
}

echo ""
echo "  [init & kabuk]"
check_file "init"     "/sbin/init"
check_file "busybox"  "/bin/busybox"
check_file "sh"       "/bin/sh"
check_file "bash"     "/bin/bash"

echo ""
echo "  [araçlar]"
check_file "wget"     "/usr/bin/wget"
check_file "curl"     "/usr/bin/curl"
check_file "nano"     "/usr/bin/nano"
check_file "sudo"     "/usr/bin/sudo"

echo ""
echo "  [paket yöneticisi]"
check_file "xbps-install" "/usr/bin/xbps-install"
check_file "pacman"       "/usr/bin/pacman"

echo ""
echo "  [init sistemi]"
check_file "openrc"       "/sbin/openrc"
check_file "sysvinit"     "/usr/sbin/init"
check_file "inittab"      "/etc/inittab"

echo ""
echo "  [etc dosyaları]"
check_file "hostname"  "/etc/hostname"
check_file "fstab"     "/etc/fstab"
check_file "passwd"    "/etc/passwd"
check_file "sudoers"   "/etc/sudoers"
check_file "nanorc"    "/etc/nanorc"
check_file "profile"   "/etc/profile"

echo ""
echo "  [kütüphaneler]"
check_file "libc.so.6" "/usr/lib/x86_64-linux-gnu/libc.so.6"
check_file "ld-linux"  "/lib64/ld-linux-x86-64.so.2"

echo ""
echo "  [dizin boyutu]"
du -sh "$ROOTFS_DIR" 2>/dev/null | awk '{print "  📦 Toplam: " $1}'

echo ""
echo "  [en büyük dizinler]"
du -sh "$ROOTFS_DIR"/* 2>/dev/null | sort -rh | head -10 | \
    awk '{print "    " $1 "\t" $2}' | \
    sed "s|${ROOTFS_DIR}||"

echo ""
echo "=========================================="
echo "==> RootFS hazır ✓"
echo "=========================================="
