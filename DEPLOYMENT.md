# Deployment Guide - Railway & Custom Domain

## Prerequisites
- Akun GitHub (untuk login ke Railway)
- Akun Registrar Domain (untuk setup domain custom, contoh: Namecheap, GoDaddy, Cloudflare, dll)
- Jamendo API credentials (sudah ada: `d945bbd0` dan `91b20fea24d178532ff95f9b8f21657e`)

## Step 1: Deploy ke Railway

### 1.1 Login ke Railway
```bash
# Buka https://railway.app
# Login dengan GitHub account
```

### 1.2 Create New Project
1. Click "+ New Project"
2. Pilih "Deploy from GitHub repo"
3. Authorize Railway ke GitHub account Anda
4. Pilih repository `Web-Musik-FahriGenzVibe`
5. Click "Deploy Now"

Railway akan otomatis:
- Detect Dockerfile/Procfile
- Build Docker image
- Deploy aplikasi
- Assign URL public (contoh: `webmusik-fahrigenzvibe.railway.app`)

### 1.3 Setup Environment Variables di Railway
1. Buka project di Railway dashboard
2. Go to "Variables" tab
3. Add dua variables:
   - `JAMENDO_CLIENT_ID`: `d945bbd0`
   - `JAMENDO_CLIENT_SECRET`: `91b20fea24d178532ff95f9b8f21657e`

4. Deploy akan restart otomatis dengan variables baru

## Step 2: Setup Custom Domain

### 2.1 Di Railway Dashboard
1. Buka project Anda di Railway
2. Go ke "Settings" tab
3. Cari section "Domain"
4. Click "+ Add Domain"
5. Masukkan domain: `webmusik-fahrigenzvibe.com`
6. Railway akan generate CNAME record

### 2.2 Di Domain Registrar (Namecheap / GoDaddy / etc)
1. Login ke registrar Anda
2. Cari "DNS Settings" atau "Manage DNS"
3. Tambah CNAME record baru:
   - **Name/Host**: `@` atau `webmusik` (tergantung registrar)
   - **Value/Points to**: CNAME value dari Railway (contoh: `webmusik-fahrigenzvibe.railway.app`)
   - **TTL**: 3600

Contoh untuk Cloudflare:
```
Type: CNAME
Name: webmusik-fahrigenzvibe.com (atau @)
Content: <railway-generated-cname>
TTL: Auto
Proxy: DNS only
```

### 2.3 Wait for DNS Propagation
DNS biasanya update dalam 5-30 menit. Cek status di Railway dashboard atau:
```bash
nslookup webmusik-fahrigenzvibe.com
# atau
dig webmusik-fahrigenzvibe.com
```

## Step 3: Test Deployment

### Test API Endpoints
```bash
# Search endpoint
curl "https://webmusik-fahrigenzvibe.com/api/search?q=lagu%20favorit"

# Playlists endpoint
curl "https://webmusik-fahrigenzvibe.com/api/playlists?user=testuser"

# Web UI
https://webmusik-fahrigenzvibe.com
```

### Jika Ada Error
1. Check Railway logs: Dashboard → Logs tab
2. Verify environment variables sudah set
3. Verify domain DNS record correct

## Step 4: Update Frontend URLs (Optional)

Jika Flutter app atau frontend HTML menggunakan hardcoded URL, update ke domain baru:

**Di `index.html`:**
```javascript
const API = 'https://webmusik-fahrigenzvibe.com/api/search?q=';
```

**Di `flutter_app/lib/main.dart`:**
```dart
const serverBase = 'https://webmusik-fahrigenzvibe.com';
```

## Features yang Sudah Setup

✅ **Unlimited Results**: Increased limit dari 50 → 200 results
✅ **Extended Timeout**: Increased timeout dari 10 → 30 detik
✅ **CORS Enabled**: Public API accessible dari semua domain
✅ **Production Ready**: Debug mode disabled, gunicorn ready
✅ **Environment Variables**: PORT dan Jamendo credentials support

## Monitoring & Maintenance

### Railroad Dashboard
- Logs: Lihat real-time logs di Railway dashboard
- Metrics: Monitor CPU, Memory, Network
- Deployments: Lihat history deployment
- Rollback: Bisa rollback ke deployment sebelumnya

### Auto-Deploy
Setiap push ke branch `main` akan otomatis trigger deploy baru ke Railway.

### Custom Domain SSL/TLS
Railway otomatis provide SSL certificate untuk custom domain (Let's Encrypt).

## Troubleshooting

| Issue | Solusi |
|-------|--------|
| 400 Bad Request | Verify JAMENDO_CLIENT_ID di Railway variables |
| Domain not working | Check DNS propagation, wait 5-30 menit |
| Timeout errors | Already extended to 30 sec, check Jamendo API status |
| CORS errors | CORS already enabled di app.py |

---

**Note**: Aplikasi sekarang siap untuk production tanpa batasan atau mock data!
