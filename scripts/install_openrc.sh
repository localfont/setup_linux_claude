#!/usr/bin/env bash
# ============================================================
# install_openrc.sh — OpenRC init sistemini kur ve yapılandır
# ============================================================
set -euo pipefail

ROOTFS_DIR="${ROOTFS_DIR:-/tmp/rootfs}"
PKG_MANAGER="${PKG_MANAGER:-xbps}"
VOID_MIRROR="https://repo-default.voidlinux.org/current"

echo "==> OpenRC init sistemi kuruluyor..."

# ---- xbps ile kur ----
if [ "$PKG_MANAGER" = "xbps" ]; then
    XBPS_INSTALL=$(find /tmp/xbps-static -name "xbps-install.static" 2>/dev/null | head -1)
    [ -z "$XBPS_INSTALL" ] && XBPS_INSTALL="$ROOTFS_DIR/usr/bin/xbps-install"

    sudo "$XBPS_INSTALL" \
        -r "$ROOTFS_DIR" \
        --repository="$VOID_MIRROR" \
        -y \
        openrc runit-void 2>&1 || \
    sudo "$XBPS_INSTALL" \
        -r "$ROOTFS_DIR" \
        --repository="$VOID_MIRROR" \
        -y \
        openrc 2>&1 || true

# ---- pacman ile kur ----
else
    sudo chroot "$ROOTFS_DIR" /usr/bin/pacman \
        -Sy --noconfirm openrc 2>&1 || \
    sudo chroot "$ROOTFS_DIR" /usr/bin/pacman \
        -Sy --noconfirm openrc-openrc 2>&1 || true
fi

# ---- OpenRC kaynak derle (paket başarısız olursa) ----
if [ ! -f "$ROOTFS_DIR/sbin/openrc" ] && [ ! -f "$ROOTFS_DIR/usr/sbin/openrc" ]; then
    echo "  -> OpenRC paketten bulunamadı, kaynaktan derleniyor..."
    OPENRC_VERSION="0.55"
    OPENRC_SRC="/tmp/openrc-src"

    apt-get install -y meson ninja-build pkg-config 2>/dev/null || true

    mkdir -p "$OPENRC_SRC"
    wget -q -O "$OPENRC_SRC/openrc.tar.gz" \
        "https://github.com/OpenRC/openrc/archive/refs/tags/${OPENRC_VERSION}.tar.gz"
    tar -xf "$OPENRC_SRC/openrc.tar.gz" -C "$OPENRC_SRC"

    cd "$OPENRC_SRC/openrc-${OPENRC_VERSION}"
    meson setup build \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
        -Dpkg_prefix="$ROOTFS_DIR" \
        -Dbranding="BusyBox Linux" \
        -Dos=Linux \
        -Dpam=false \
        -Dselinux=disabled 2>&1 | tail -5

    ninja -C build -j"$(nproc)"
    DESTDIR="$ROOTFS_DIR" ninja -C build install
fi

# ---- OpenRC servis dizinleri ----
echo "  -> OpenRC dizin yapısı oluşturuluyor..."
sudo mkdir -p "$ROOTFS_DIR"/{etc/{init.d,conf.d,runlevels/{boot,default,nonetwork,shutdown,sysinit}},\
lib/rc/{sh,tmp},var/{lib/rc/tmp,log/rc}}

# ---- Temel init.d servisleri ----
echo "  -> Temel init.d servisleri oluşturuluyor..."

# /etc/init.d/hostname
sudo tee "$ROOTFS_DIR/etc/init.d/hostname" > /dev/null <<'INITEOF'
#!/sbin/openrc-run
description="Hostname ayarla"

start() {
    ebegin "Hostname ayarlanıyor"
    hostname $(cat /etc/hostname 2>/dev/null || echo "busybox-linux")
    eend $?
}
INITEOF

# /etc/init.d/networking
sudo tee "$ROOTFS_DIR/etc/init.d/networking" > /dev/null <<'INITEOF'
#!/sbin/openrc-run
description="Ağ arayüzleri"

depend() {
    need net.lo
}

start() {
    ebegin "Ağ başlatılıyor"
    ip link set lo up 2>/dev/null || ifconfig lo up 2>/dev/null
    eend $?
}
INITEOF

# /etc/init.d/syslog (BusyBox syslogd)
sudo tee "$ROOTFS_DIR/etc/init.d/syslog" > /dev/null <<'INITEOF'
#!/sbin/openrc-run
description="Sistem günlüğü (BusyBox syslogd)"

command="/sbin/syslogd"
command_args="-n"
pidfile="/run/syslogd.pid"

depend() {
    need localmount
}
INITEOF

# /etc/inittab (BusyBox init ile uyumlu, OpenRC'nin başlatması için)
sudo tee "$ROOTFS_DIR/etc/inittab" > /dev/null <<'INITEOF'
# /etc/inittab — BusyBox init + OpenRC

# Sistem başlatma
::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default

# Getty — sanal terminaller
tty1::respawn:/sbin/getty -L tty1 0 vt100
tty2::respawn:/sbin/getty -L tty2 0 vt100
tty3::respawn:/sbin/getty -L tty3 0 vt100

# Seri port (isteğe bağlı)
#ttyS0::respawn:/sbin/getty -L ttyS0 115200 vt100

# Yeniden başlatma sinyalleri
::ctrlaltdel:/sbin/reboot
::shutdown:/sbin/openrc shutdown
::restart:/sbin/openrc shutdown
INITEOF

# Runlevel sembolik linkleri
echo "  -> Runlevel servisleri etkinleştiriliyor..."
for svc in hostname networking syslog; do
    [ -f "$ROOTFS_DIR/etc/init.d/$svc" ] && {
        sudo chmod +x "$ROOTFS_DIR/etc/init.d/$svc"
        sudo ln -sf "/etc/init.d/$svc" \
            "$ROOTFS_DIR/etc/runlevels/default/$svc" 2>/dev/null || true
    }
done

# OpenRC konfigürasyonu
sudo tee "$ROOTFS_DIR/etc/rc.conf" > /dev/null <<'EOF'
# OpenRC ana konfigürasyonu
unicode="YES"
keymap="trq"
consolefont=""
consoletrans=""
EDITOR="/usr/bin/nano"
PAGER="/usr/bin/less"
EOF

echo "==> OpenRC kuruldu ve yapılandırıldı ✓"
