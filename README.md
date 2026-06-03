# FahriGenzVibe - Python (Flask) version

Menjalankan versi sederhana menggunakan Flask. Aplikasi HTML menggunakan Jamendo API sebagai sumber audio penuh untuk memutar lagu.

Cara menjalankan:

1. Buat virtual environment dan install dependensi:

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

2. Jalankan server:

```bash
python app.py

```

3. Buka http://localhost:8000 di browser.

Catatan: Jika ingin frontend memanggil API melalui proxy lokal (menghindari CORS), ubah konstanta `API` di `index.html` menjadi `/api/search?q=`.
Untuk memutar lagu penuh dari Jamendo, jalankan server dengan environment variable `JAMENDO_CLIENT_ID` dan `JAMENDO_CLIENT_SECRET` yang valid:

```bash
export JAMENDO_CLIENT_ID=d945bbd0
export JAMENDO_CLIENT_SECRET=91b20fea24d178532ff95f9b8f21657e
python app.py
```
Tanpa key yang valid, backend tidak akan menyediakan audio penuh.
# Web-Musik-FahriGenzVibe