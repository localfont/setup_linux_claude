# 🐧 BusyBox AMD64 glibc RootFS Builder

GitHub Actions ile otomatik olarak derlenen minimal Linux root filesystem.

## 📦 İçerik

| Bileşen | Detay |
|---------|-------|
| **BusyBox** | v1.36.1, AMD64, glibc bağlı |
| **libc** | glibc (dinamik) |
| **Paket yöneticisi** | `xbps` (Void Linux) veya `pacman` (Arch Linux) |
| **Init sistemi** | `OpenRC` veya `SysVinit` |
| **Araçlar** | wget, curl, nano, sudo, bash |

## 🚀 Kullanım

### GitHub Actions'da Derle

1. Bu repoyu fork'la veya klonla
2. **Actions** sekmesine git
3. **Build BusyBox AMD64 glibc RootFS** workflow'unu seç
4. **Run workflow** → seçenekleri belirle:
   - `pkg_manager`: `xbps` veya `pacman`
   - `init_system`: `openrc` veya `sysvinit`
5. Artifact olarak `rootfs-busybox-amd64-*.tar.xz` indir

### Lokal Test (Docker)

```bash
# rootfs arşivini aç
mkdir -p ./rootfs
tar -xJf rootfs-busybox-amd64-xbps-openrc.tar.xz -C ./rootfs

# chroot ile test et
sudo chroot ./rootfs /bin/sh

# Veya systemd-nspawn ile
sudo systemd-nspawn -D ./rootfs --boot
```

### QEMU ile Boot Et

```bash
# initramfs oluştur
cd ./rootfs
find . | cpio -H newc -o | gzip > ../initramfs.cpio.gz

# QEMU boot
qemu-system-x86_64 \
  -kernel /boot/vmlinuz \
  -initrd ../initramfs.cpio.gz \
  -append "init=/sbin/init console=ttyS0" \
  -nographic \
  -m 512M
```

## 📂 Repo Yapısı

```
.
├── .github/
│   └── workflows/
│       └── build.yml          # Ana workflow
└── scripts/
    ├── build_busybox.sh       # BusyBox derleme
    ├── bootstrap_rootfs.sh    # Dizin yapısı + glibc
    ├── install_xbps.sh        # xbps paket yöneticisi
    ├── install_pacman.sh      # pacman paket yöneticisi
    ├── install_pkgs_xbps.sh   # wget/curl/nano/sudo (xbps)
    ├── install_pkgs_pacman.sh # wget/curl/nano/sudo (pacman)
    ├── install_openrc.sh      # OpenRC init sistemi
    ├── install_sysvinit.sh    # SysVinit init sistemi
    └── finalize_rootfs.sh     # Son ayarlar + doğrulama
```

## ⚙️ Özelleştirme

### BusyBox sürümünü değiştir
`build.yml` dosyasında:
```yaml
env:
  BUSYBOX_VERSION: "1.36.1"   # ← burası
```

### Paket ekle (xbps)

`install_pkgs_xbps.sh` dosyasındaki `PACKAGES` listesine ekle:
```bash
PACKAGES=(
    wget curl nano sudo
    htop        # ← yeni paket
    openssh     # ← yeni paket
)
```

### Paket ekle (pacman)

`install_pkgs_pacman.sh` dosyasındaki `PACKAGES` listesine ekle.

### Yeni servis ekle (OpenRC)

`install_openrc.sh` dosyasına:
```bash
sudo tee "$ROOTFS_DIR/etc/init.d/myservice" > /dev/null <<'EOF'
#!/sbin/openrc-run
start() { ebegin "Servis başlatılıyor"; mybin &; eend $?; }
stop()  { ebegin "Servis durduruluyor"; killall mybin; eend $?; }
EOF
sudo chmod +x "$ROOTFS_DIR/etc/init.d/myservice"
sudo ln -sf /etc/init.d/myservice "$ROOTFS_DIR/etc/runlevels/default/myservice"
```

## 📋 Notlar

- Rootfs **dinamik glibc** ile bağlıdır; statik derlemek için `build_busybox.sh`'da
  `CONFIG_STATIC=y` ayarını etkinleştir
- xbps Void Linux mirror'ından paket çeker
- pacman Arch Linux mirror'ından paket çeker
- Artifact 30 gün saklanır
