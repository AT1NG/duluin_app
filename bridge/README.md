# Duluin Bridge - Firebase Firestore to WAHA

Script ini bertugas memantau database **Firebase Firestore Cloud** dari HP Anda secara real-time, lalu memicu pengiriman pesan WhatsApp otomatis melalui **WAHA** lokal di PC/Laptop Anda ketika tugas mendekati deadline (H-1 Hari atau H-1 Jam).

## Persyaratan
1. **Node.js** terinstal di PC/Laptop Anda (Unduh dari [nodejs.org](https://nodejs.org/)).
2. **WAHA** berjalan di PC/Laptop Anda (pada `http://localhost:3000`).

---

## Cara Setup & Menjalankan Bridge

### Langkah 1: Unduh Kunci Akun Layanan Firebase (`serviceAccountKey.json`)
Agar script ini bisa membaca database Firebase Firestore Anda secara aman, Anda memerlukan file kunci kredensial:
1. Buka **Firebase Console** (https://console.firebase.google.com/) dan masuk ke project Anda.
2. Klik ikon gerigi **Project Settings** (Setelan Proyek) di pojok kiri atas.
3. Masuk ke tab **Service Accounts** (Akun Layanan).
4. Klik tombol **Generate new private key** (Buat kunci privat baru) di bagian bawah.
5. Unduh file JSON yang dihasilkan, lalu **ubah namanya** menjadi `serviceAccountKey.json`.
6. Pindahkan/salin file `serviceAccountKey.json` tersebut ke dalam folder ini (`duluin/bridge/`).

### Langkah 2: Install Dependencies
Buka **Command Prompt (CMD)** atau terminal di PC Anda, lalu arahkan ke folder `bridge` ini dan jalankan perintah:
```bash
npm install
```

### Langkah 3: Jalankan Bridge
Jalankan perintah ini di CMD folder `bridge` untuk mulai memantau database dan mengirim pesan WA otomatis:
```bash
npm start
```

---

## Catatan Penting
* **Laptop/PC harus menyala** saat waktu pengingat tiba agar script ini bisa berjalan dan memanggil WAHA untuk mengirim pesan.
* HP fisik Anda sekarang bebas menggunakan **data seluler** untuk menambah/mengedit tugas dari luar rumah, karena data tugas langsung masuk ke database Firebase Cloud.
