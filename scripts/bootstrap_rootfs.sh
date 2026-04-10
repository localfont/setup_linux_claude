#!/usr/bin/env bash
# ============================================================
# bootstrap_rootfs.sh — Temel dizin yapısı ve glibc kurulumu
# ============================================================
set -euo pipefail

ROOTFS_DIR="${ROOTFS_DIR:-/tmp/rootfs}"

echo "==> RootFS iskelet yapısı oluşturuluyor: $ROOTFS_DIR"

# FHS dizin yapısı
sudo mkdir -p "$ROOTFS_DIR"/{bin,sbin,usr/{bin,sbin,lib,lib64,include,share},lib,lib64,\
etc/{init.d,network,profile.d,cron.d},var/{log,run,lib/xbps,cache},\
tmp,proc,sys,dev,run,home,root,mnt,opt,srv}

# /usr/bin → /bin sembolik link (modern FHS)
sudo ln -sf usr/bin  "$ROOTFS_DIR/bin"  2>/dev/null || true
sudo ln -sf usr/sbin "$ROOTFS_DIR/sbin" 2>/dev/null || true
sudo ln -sf usr/lib  "$ROOTFS_DIR/lib"  2>/dev/null || true
sudo ln -sf usr/lib  "$ROOTFS_DIR/lib64" 2>/dev/null || true

# Glibc dinamik kütüphanelerini host'tan kopyala
echo "  -> glibc kütüphaneleri kopyalanıyor..."
GLIBC_LIBS=(
    /lib/x86_64-linux-gnu/libc.so.6
    /lib/x86_64-linux-gnu/libm.so.6
    /lib/x86_64-linux-gnu/libpthread.so.0
    /lib/x86_64-linux-gnu/libdl.so.2
    /lib/x86_64-linux-gnu/librt.so.1
    /lib/x86_64-linux-gnu/libresolv.so.2
    /lib/x86_64-linux-gnu/libnss_dns.so.2
    /lib/x86_64-linux-gnu/libnss_files.so.2
    /lib/x86_64-linux-gnu/libnss_compat.so.2
    /lib/x86_64-linux-gnu/libssl.so.3
    /lib/x86_64-linux-gnu/libcrypto.so.3
    /lib/x86_64-linux-gnu/libz.so.1
    /lib/x86_64-linux-gnu/liblzma.so.5
    /lib/x86_64-linux-gnu/libbz2.so.1.0
    /lib/x86_64-linux-gnu/libzstd.so.1
)

sudo mkdir -p "$ROOTFS_DIR/usr/lib/x86_64-linux-gnu"
for lib in "${GLIBC_LIBS[@]}"; do
    [ -f "$lib" ] && sudo cp -a "$lib" "$ROOTFS_DIR/usr/lib/x86_64-linux-gnu/" || true
done

# ld-linux bağlayıcısı (kritik!)
LD_FILE=$(find /lib/x86_64-linux-gnu/ -name "ld-linux-x86-64.so*" 2>/dev/null | head -1)
if [ -n "$LD_FILE" ]; then
    sudo cp -a "$LD_FILE" "$ROOTFS_DIR/usr/lib/x86_64-linux-gnu/"
    sudo mkdir -p "$ROOTFS_DIR/lib64"
    sudo ln -sf "/usr/lib/x86_64-linux-gnu/$(basename $LD_FILE)" \
        "$ROOTFS_DIR/lib64/ld-linux-x86-64.so.2" 2>/dev/null || true
fi

# ldconfig
echo "$ROOTFS_DIR/usr/lib/x86_64-linux-gnu" | \
    sudo tee "$ROOTFS_DIR/etc/ld.so.conf.d/x86_64.conf" > /dev/null
echo "/usr/lib" | sudo tee -a "$ROOTFS_DIR/etc/ld.so.conf" > /dev/null
echo "/usr/lib/x86_64-linux-gnu" | sudo tee -a "$ROOTFS_DIR/etc/ld.so.conf" > /dev/null

# /dev düğümleri
echo "  -> /dev düğümleri oluşturuluyor..."
sudo mknod -m 666 "$ROOTFS_DIR/dev/null"    c 1 3  2>/dev/null || true
sudo mknod -m 666 "$ROOTFS_DIR/dev/zero"    c 1 5  2>/dev/null || true
sudo mknod -m 666 "$ROOTFS_DIR/dev/random"  c 1 8  2>/dev/null || true
sudo mknod -m 666 "$ROOTFS_DIR/dev/urandom" c 1 9  2>/dev/null || true
sudo mknod -m 600 "$ROOTFS_DIR/dev/console" c 5 1  2>/dev/null || true
sudo mknod -m 666 "$ROOTFS_DIR/dev/tty"     c 5 0  2>/dev/null || true

# Temel /etc dosyaları
echo "  -> Temel /etc dosyaları yazılıyor..."

sudo tee "$ROOTFS_DIR/etc/hostname" > /dev/null <<'EOF'
busybox-linux
EOF

sudo tee "$ROOTFS_DIR/etc/hosts" > /dev/null <<'EOF'
127.0.0.1   localhost
127.0.1.1   busybox-linux
::1         localhost ip6-localhost ip6-loopback
EOF

sudo tee "$ROOTFS_DIR/etc/resolv.conf" > /dev/null <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

sudo tee "$ROOTFS_DIR/etc/passwd" > /dev/null <<'EOF'
root:x:0:0:root:/root:/bin/sh
nobody:x:65534:65534:nobody:/:/sbin/nologin
EOF

sudo tee "$ROOTFS_DIR/etc/group" > /dev/null <<'EOF'
root:x:0:root
wheel:x:10:root
users:x:1000:
nobody:x:65534:
EOF

sudo tee "$ROOTFS_DIR/etc/shadow" > /dev/null <<'EOF'
root:!:19000:0:99999:7:::
nobody:!:19000:::::::
EOF
sudo chmod 600 "$ROOTFS_DIR/etc/shadow"

sudo tee "$ROOTFS_DIR/etc/profile" > /dev/null <<'EOF'
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export TERM=linux
export HOME=/root
export USER=root

# Renk promptu
PS1='\[\033[01;31m\]\u\[\033[00m\]@\[\033[01;34m\]\h\[\033[00m\]:\[\033[01;33m\]\w\[\033[00m\]\$ '

[ -d /etc/profile.d ] && for f in /etc/profile.d/*.sh; do . "$f"; done
EOF

sudo tee "$ROOTFS_DIR/etc/shells" > /dev/null <<'EOF'
/bin/sh
/bin/ash
/bin/bash
EOF

sudo tee "$ROOTFS_DIR/etc/fstab" > /dev/null <<'EOF'
# <device>  <mountpoint>  <type>  <options>        <dump> <pass>
proc        /proc         proc    defaults          0      0
sysfs       /sys          sysfs   defaults          0      0
devtmpfs    /dev          devtmpfs defaults          0      0
tmpfs       /tmp          tmpfs   defaults,nosuid   0      0
EOF

sudo chmod 755 "$ROOTFS_DIR"
sudo chmod 1777 "$ROOTFS_DIR/tmp"
sudo chmod 700 "$ROOTFS_DIR/root"

echo "==> RootFS iskelet hazır ✓"
