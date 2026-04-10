#!/usr/bin/env bash
# ============================================================
# install_sysvinit.sh — SysVinit + inittab yapılandırması
# ============================================================
set -euo pipefail

ROOTFS_DIR="${ROOTFS_DIR:-/tmp/rootfs}"
PKG_MANAGER="${PKG_MANAGER:-xbps}"
VOID_MIRROR="https://repo-default.voidlinux.org/current"
SYSVINIT_VERSION="3.09"

echo "==> SysVinit ${SYSVINIT_VERSION} kuruluyor..."

# ---- xbps ile kur ----
if [ "$PKG_MANAGER" = "xbps" ]; then
    XBPS_INSTALL=$(find /tmp/xbps-static -name "xbps-install.static" 2>/dev/null | head -1)
    [ -z "$XBPS_INSTALL" ] && XBPS_INSTALL="$ROOTFS_DIR/usr/bin/xbps-install"

    sudo "$XBPS_INSTALL" \
        -r "$ROOTFS_DIR" \
        --repository="$VOID_MIRROR" \
        -y \
        sysvinit 2>&1 || true

# ---- pacman ile kur ----
elif [ "$PKG_MANAGER" = "pacman" ]; then
    sudo chroot "$ROOTFS_DIR" /usr/bin/pacman \
        -Sy --noconfirm sysvinit 2>&1 || true
fi

# ---- Paket başarısız olduysa kaynaktan derle ----
if [ ! -f "$ROOTFS_DIR/sbin/init" ] && [ ! -f "$ROOTFS_DIR/usr/sbin/init" ]; then
    echo "  -> SysVinit paketten bulunamadı, kaynaktan derleniyor..."
    SYSVINIT_SRC="/tmp/sysvinit-src"
    mkdir -p "$SYSVINIT_SRC"

    wget -q -O "$SYSVINIT_SRC/sysvinit.tar.xz" \
        "https://github.com/slicer69/sysvinit/releases/download/${SYSVINIT_VERSION}/sysvinit-${SYSVINIT_VERSION}.tar.xz"
    tar -xf "$SYSVINIT_SRC/sysvinit.tar.xz" -C "$SYSVINIT_SRC"

    cd "$SYSVINIT_SRC/sysvinit-${SYSVINIT_VERSION}"
    make -j"$(nproc)" 2>&1 | tail -10
    make install ROOT="$ROOTFS_DIR" 2>&1 | tail -10
fi

# ---- rc-scripts / initscripts ----
echo "  -> init script'leri oluşturuluyor..."
sudo mkdir -p "$ROOTFS_DIR"/{etc/{init.d,rc.d,rc{0,1,2,3,4,5,6}.d},sbin}

# /etc/rc — Ana başlatma betiği
sudo tee "$ROOTFS_DIR/etc/rc" > /dev/null <<'RCEOF'
#!/bin/sh
# /etc/rc — Sistem başlatma

PATH=/sbin:/usr/sbin:/bin:/usr/bin
export PATH

echo "BusyBox Linux başlatılıyor..."

# proc / sys / dev mount
mount -t proc  proc  /proc  2>/dev/null
mount -t sysfs sysfs /sys   2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null

# Hostname ayarla
[ -f /etc/hostname ] && hostname $(cat /etc/hostname)

# Ağ başlat
ip link set lo up 2>/dev/null || ifconfig lo up 2>/dev/null

# init.d servisleri başlat
for script in /etc/init.d/S*; do
    [ -x "$script" ] && "$script" start
done

echo "Sistem hazır."
RCEOF
sudo chmod +x "$ROOTFS_DIR/etc/rc"

# /etc/inittab — SysVinit konfigürasyonu
sudo tee "$ROOTFS_DIR/etc/inittab" > /dev/null <<'INITEOF'
# /etc/inittab — SysVinit yapılandırması

# Varsayılan runlevel
id:3:initdefault:

# Sistem başlatma
si::sysinit:/etc/rc

# Runlevel 0 = Kapat
l0:0:wait:/etc/rc.d/rc 0
# Runlevel 1 = Tek kullanıcı
l1:1:wait:/etc/rc.d/rc 1
# Runlevel 2-5 = Çok kullanıcı
l2:2:wait:/etc/rc.d/rc 2
l3:3:wait:/etc/rc.d/rc 3
l4:4:wait:/etc/rc.d/rc 4
l5:5:wait:/etc/rc.d/rc 5
# Runlevel 6 = Yeniden başlat
l6:6:wait:/etc/rc.d/rc 6

# Konsol terminalleri
1:2345:respawn:/sbin/getty 38400 tty1
2:2345:respawn:/sbin/getty 38400 tty2
3:2345:respawn:/sbin/getty 38400 tty3

# Seri port (isteğe bağlı, etkinleştirmek için # kaldır)
#S0:2345:respawn:/sbin/getty -L 115200 ttyS0 vt100

# Ctrl+Alt+Del
ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now

# Kapatma işlemleri
pf::powerfail:/sbin/shutdown -h +2 "Güç kesildi!"
pr:12345:powerokwait:/sbin/shutdown -c "Güç geri geldi"
INITEOF

# rc.d ana betiği
sudo tee "$ROOTFS_DIR/etc/rc.d/rc" > /dev/null <<'RCEOF'
#!/bin/sh
# /etc/rc.d/rc — Runlevel geçiş yöneticisi
RUNLEVEL=$1
PREVLEVEL=$(runlevel | awk '{print $1}')

for script in /etc/rc${RUNLEVEL}.d/K*; do
    [ -x "$script" ] && "$script" stop
done
for script in /etc/rc${RUNLEVEL}.d/S*; do
    [ -x "$script" ] && "$script" start
done
RCEOF
sudo chmod +x "$ROOTFS_DIR/etc/rc.d/rc"

# Temel S* servisleri
sudo tee "$ROOTFS_DIR/etc/init.d/S01syslog" > /dev/null <<'EOF'
#!/bin/sh
case "$1" in
    start) syslogd; klogd ;;
    stop)  killall syslogd; killall klogd ;;
esac
EOF

sudo tee "$ROOTFS_DIR/etc/init.d/S10network" > /dev/null <<'EOF'
#!/bin/sh
case "$1" in
    start)
        echo "Ağ başlatılıyor..."
        ip link set lo up 2>/dev/null || ifconfig lo up
        ;;
    stop)
        ip link set lo down 2>/dev/null || ifconfig lo down
        ;;
esac
EOF

# Runlevel 3 linkleri
for svc in S01syslog S10network; do
    sudo chmod +x "$ROOTFS_DIR/etc/init.d/$svc"
    sudo ln -sf "/etc/init.d/$svc" "$ROOTFS_DIR/etc/rc3.d/$svc" 2>/dev/null || true
done

echo "==> SysVinit kuruldu ve yapılandırıldı ✓"
