# Saku — Asisten Pengeluaran

Aplikasi Android untuk mencatat pengeluaran, **100% offline**, dengan agent lokal yang bisa diajak ngobrol lewat teks/suara: catat pengeluaran (`"makan bakso 25 ribu"`), minta grafik bentuk lain (`"ubah grafik jadi pie"`), tentukan rentang tanggal (`"tampilkan pengeluaran 1-7 Oktober"`), sampai menambah/menghapus kartu dashboard.

## Fitur

- **Baca notifikasi HP** — `NotificationListenerService`. Notifikasi Gopay/OVO/bank yang mengandung nominal dikumpulkan jadi draft, lalu selesai lewat tombol konfirmasi (atau langsung tercatat kalau auto-add aktif).
- **Input suara** — SpeechRecognizer Android dengan bahasa Indonesia; bisa offline kalau engine pada HP mendukung offline.
- **Data survivor uninstall** — semua data disimpan sebagai JSON di folder bersama yang kamu pilih lewat picker Android (SAF). Kalau aplikasi dibongkar, isi folder ini tetap ada; pasang lagi lalu pilih folder yang sama, datanya langsung kembali.
- **Bisa dibuka dari laptop** — file JSON-nya bisa dibuka lewat aplikasi file/Drive. Pilih folder di Google Drive saat pemilihan folder pertama supaya isinya otomatis tersinkron ke cloud, lalu bisa dibaca dari laptop tanpa harus satu Wi-Fi. Untuk format yang rapi, ada `Setelan → Ekspor CSV`.
- **Desain minimalis ala Apple** dengan mascot "Saku" (kantong uang lucu) yang digambar langsung di Compose, tanpa aset gambar.

## Cara pakai

1. Pasang APK, lalu buka Saku dan pilih folder penyimpanan (langkah pertama yang wajib).
2. (Opsional) Aktifkan izin "Notification access" untuk fitur baca-notifikasi, dan izin mikrofon untuk input suara.
3. Ketik atau pakai suara di dasbor/tab Agent: `"makan bakso 25 ribu"`, `"ubah grafik jadi line"`, `"tambah kartu bar 7 hari"`, `"rekap minggu ini"`.
4. Draft dari notifikasi muncul di tab Konfirmasi — tap "Catat" untuk menyetujui.

## Build

Build otomatis jalan di GitHub Actions setiap push ke `main`:

- APK signed tersimpan sebagai artifact `Saku-APK` di halaman Actions.
- File `apk/Saku-1.0.0-release.apk` ikut di-commit ke repo.
- Push tag `v1.0.0` (misal) untuk menciptakan GitHub Release dengan APK terlampir.

Untuk Android Studio: JDK 17, Gradle 8.10.2, AGP 8.7.3, minSdk 26, compileSdk/targetSdk 35.

## Keystore (signing)

`keystore/zwart-money-agent.jks` ikut di-commit supaya update APK tetap bisa dipasang over-the-top tanpa uninstall:

- alias: `zwartmoney`
- store/key password: `zwartmoney2026`

## Struktur

```
app/src/main/java/id/zwart/saku/
├── MainActivity.kt
├── SakuApp.kt            ← seluruh UI Compose (dasbor, agent, konfirmasi, setelan)
├── ai/LocalAgent.kt      ← NLU agent lokal (perintah → aksi)
├── data/Models.kt        ← model + JSON serializer
├── data/ExpenseRepository.kt
├── notifications/…       ← pembaca notifikasi keuangan
├── storage/FolderStore.kt← penyimpanan SAF survival-uninstall
└── voice/VoiceInput.kt   ← input suara
```
