# 🛡️ F2B-Alert: Fail2ban Telegram Monitor

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)

> Monitor keamanan server Anda dengan notifikasi real-time melalui Telegram!

## 📋 Fitur Utama
- 🔔 Notifikasi real-time via Telegram
- 🌍 Analisis geografis IP yang diblokir
- 📊 Statistik dan ringkasan keamanan
- 🖥️ Informasi sistem yang lengkap
- 📝 Logging untuk monitoring
- ⚡ Ringan dan mudah dikonfigurasi

## 🚀 Instalasi

### Prasyarat
```bash
# Install dependencies yang diperlukan
sudo dnf install whois curl
```

### Langkah Instalasi
1. Clone repository
```bash
git clone https://github.com/username/f2b-alert.git
cd f2b-alert
```

2. Buat script executable
```bash
chmod +x f2bstat.sh
```

3. Jalankan script untuk membuat struktur konfigurasi
```bash
sudo ./f2bstat.sh
```

4. Edit file konfigurasi
```bash
sudo nano /etc/f2bstat/config.conf
```

5. Masukkan Bot Token dan Chat ID Telegram Anda
```bash
BOT_TOKEN="YOUR_BOT_TOKEN"
CHAT_ID="YOUR_CHAT_ID"
```

## ⚙️ Konfigurasi Cron
Untuk menjalankan monitoring setiap hari pukul 23:55:
```bash
sudo crontab -e
# Tambahkan baris berikut
55 23 * * * /path/to/f2bstat.sh 2>&1 | /usr/bin/logger -t f2bstat
```

## 📱 Format Notifikasi
### Informasi yang Ditampilkan:
- Hostname dan OS
- Kernel dan Uptime
- IP sistem
- Daftar IP yang diblokir
- Analisis geografis
- Statistik pemblokiran

## 🔍 Monitoring
Cek status script melalui log:
```bash
grep f2bstat /var/log/syslog
# atau
cat /var/log/f2bstat.log
```
