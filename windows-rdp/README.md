# Windows 11 Pro - RDP Only Edition

> Modifikasi dari [dockur/windows](https://github.com/dockur/windows) yang dikhususkan untuk menjalankan **Windows 11 Pro** dengan akses **RDP saja** (tanpa web viewer).

## 🎯 Perbedaan dengan Repository Asli

| Fitur | dockur/windows (Original) | windows-rdp (Modified) |
|-------|---------------------------|------------------------|
| Versi Windows | Banyak pilihan (XP, 7, 10, 11, Server) | Hanya Windows 11 Pro |
| Akses | Web Viewer (port 8006) + RDP | RDP saja (port 3389) |
| Ukuran Image | ~1.5GB | ~800MB (lebih ringan) |
| Kompleksitas | Tinggi | Sederhana |

## 📋 Prasyarat

### Hardware Requirements
- **CPU**: Processor dengan virtualisasi (Intel VT-x atau AMD-V)
- **RAM**: Minimum 8GB (4GB untuk VM)
- **Storage**: Minimum 80GB free space
- **OS**: Linux dengan Docker

### Software Requirements
- Docker Engine 20.10+
- Docker Compose (opsional)
- KVM support

### Verifikasi KVM
```bash
# Install cpu-checker
sudo apt install cpu-checker

# Check KVM support
sudo kvm-ok
```

Output yang diharapkan:
```
INFO: /dev/kvm exists
KVM acceleration can be used
```

## 🚀 Quick Start

### Menggunakan Docker Compose (Recommended)

```bash
# Clone atau copy project
cd windows-rdp

# Build dan jalankan
docker compose up -d

# Monitor instalasi
docker logs -f windows11-rdp
```

### Menggunakan Docker CLI

```bash
# Build image
docker build -t windows11-rdp .

# Run container
docker run -d \
  --name windows11-rdp \
  --device=/dev/kvm \
  --device=/dev/net/tun \
  --cap-add=NET_ADMIN \
  -p 3389:3389/tcp \
  -p 3389:3389/udp \
  -v $(pwd)/storage:/storage \
  windows11-rdp
```

## 🔌 Cara Koneksi RDP

### Windows (mstsc)
1. Tekan `Win + R`, ketik `mstsc`, Enter
2. Computer: `localhost` atau IP server
3. Username: `Docker`
4. Password: `admin`

### Linux (FreeRDP)
```bash
# Install FreeRDP
sudo apt install freerdp2-x11

# Connect
xfreerdp /v:localhost /u:Docker /p:admin
```

### macOS
1. Download [Microsoft Remote Desktop](https://apps.apple.com/app/microsoft-remote-desktop/id1295203466) dari App Store
2. Add PC dengan address `localhost`
3. Username: `Docker`, Password: `admin`

### Mobile (iOS/Android)
- **iOS**: [Microsoft Remote Desktop](https://apps.apple.com/app/microsoft-remote-desktop/id714464092)
- **Android**: [Microsoft Remote Desktop](https://play.google.com/store/apps/details?id=com.microsoft.rdc.androidx)

## ⚙️ Konfigurasi

### Environment Variables

| Variable | Default | Deskripsi |
|----------|---------|-----------|
| `RAM_SIZE` | `4G` | RAM untuk VM |
| `CPU_CORES` | `2` | Jumlah CPU cores |
| `DISK_SIZE` | `64G` | Ukuran virtual disk |
| `USERNAME` | `Docker` | Username Windows |
| `PASSWORD` | `admin` | Password Windows |

### Custom Configuration

```yaml
# compose.yml
services:
  windows11-rdp:
    # ...
    environment:
      RAM_SIZE: "8G"
      CPU_CORES: "4"
      DISK_SIZE: "128G"
      USERNAME: "admin"
      PASSWORD: "MySecurePassword123"
```

### Multiple Instances

Untuk menjalankan beberapa instance:

```yaml
services:
  windows11-rdp-1:
    build: .
    container_name: windows11-rdp-1
    ports:
      - "3389:3389"
    # ...

  windows11-rdp-2:
    build: .
    container_name: windows11-rdp-2
    ports:
      - "3390:3389"  # Different host port
    # ...
```

## 📁 Struktur Direktori

```
windows-rdp/
├── Dockerfile              # Docker image definition
├── compose.yml             # Docker Compose configuration
├── README.md               # Documentation
├── src/
│   └── entry.sh            # Entry point script
└── assets/
    └── win11x64-rdp.xml    # Auto-install answer file
```

## 🔧 Troubleshooting

### KVM tidak terdeteksi
```bash
# Check permissions
ls -la /dev/kvm

# Add user to kvm group
sudo usermod -aG kvm $USER

# Logout dan login kembali
```

### Container tidak bisa start
```bash
# Check logs
docker logs windows11-rdp

# Check available resources
free -h
df -h
```

### RDP tidak bisa connect
```bash
# Check if Windows is ready
docker logs windows11-rdp | grep -i "RDP"

# Wait for installation to complete (5-15 minutes)
```

### Performa lambat
```yaml
# Increase resources
environment:
  RAM_SIZE: "8G"
  CPU_CORES: "4"
```

## 📊 Timeline Instalasi

| Fase | Durasi | Deskripsi |
|------|--------|-----------|
| Download ISO | 10-30 menit | Download Windows 11 ISO (~7GB) |
| Persiapan ISO | 2-5 menit | Ekstrak dan modifikasi ISO |
| Instalasi Windows | 10-20 menit | Instalasi otomatis |
| First Boot | 2-5 menit | Setup user dan RDP |
| **Total** | **25-60 menit** | Tergantung kecepatan internet |

## 🔒 Keamanan

### Rekomendasi
1. **Ganti password default** sebelum deployment
2. **Jangan expose port 3389** ke internet tanpa VPN
3. **Gunakan firewall** untuk membatasi akses
4. **Update Windows** secara berkala

### Contoh dengan Firewall
```bash
# Hanya allow dari IP tertentu
sudo ufw allow from 192.168.1.0/24 to any port 3389
```

## 🆚 Perbandingan Akses

| Metode | Original | Modified |
|--------|----------|----------|
| Web Viewer (noVNC) | ✅ Port 8006 | ❌ Dihapus |
| RDP | ✅ Port 3389 | ✅ Port 3389 |
| VNC | ❌ | ❌ |
| SPICE | ❌ | ❌ |

## 📝 License

Modifikasi ini tetap menggunakan lisensi yang sama dengan repository asli.

### Credits
- Repository original: [dockur/windows](https://github.com/dockur/windows)
- Base image: [qemus/qemu](https://hub.docker.com/r/qemux/qemu)
- VirtIO drivers: [virtio-win](https://github.com/virtio-win/virtio-win-pkg-scripts)

## ❓ FAQ

### Q: Mengapa tidak ada web viewer?
**A:** Untuk menyederhanakan image dan fokus pada RDP yang memberikan pengalaman lebih baik dengan audio, clipboard, dan file transfer.

### Q: Bisa menggunakan Windows 10?
**A:** Repository ini dikhususkan untuk Windows 11 Pro. Untuk Windows 10, gunakan repository original.

### Q: Apakah perlu product key?
**A:** Tidak perlu untuk instalasi. Windows akan berjalan dalam mode trial. Anda bisa memasukkan product key valid nanti.

### Q: Bagaimana cara backup VM?
**A:** Backup folder `./storage` yang berisi virtual disk.

### Q: Bisakah menjalankan aplikasi berat?
**A:** Ya, dengan konfigurasi resource yang memadai:
```yaml
RAM_SIZE: "16G"
CPU_CORES: "8"
```

---

**Made with ❤️ based on [dockur/windows](https://github.com/dockur/windows)**
