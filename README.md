# Saku — Asisten Pengeluaran (Flutter)

Aplikasi Android pencatat pengeluaran **100% offline** dengan agent lokal yang bisa diajak ngobrol lewat teks/suara. Dibangun ulang dengan **Flutter 3.47** + channel native Kotlin.

## Fitur

- **AI multi-item** — `"kopi gold 7k, nescafe ice 1 renceng 13900"` langsung jadi 2 catatan terpisah dengan total ringkas. Bisa juga minta `"ubah grafik jadi pie"`, `"tampilkan pengeluaran 1-7 Oktober"`, `"tambah kartu bar 7 hari"`, `"rekap minggu ini"`.
- **Pembaca notifikasi pilihan** — saat onboarding kamu pilih app mana saja yang dipantau (whitelist). Notifikasi dari app lain tidak disentuh. Draft masuk tab Konfirmasi, atau langsung tercatat kalau auto-add aktif. Ada tombol "kirim notifikasi uji" untuk mengecek pipeline.
- **Scan struk (foto)** — pilih foto struk, ML Kit (offline) baca baris bernominal, kamu centang yang mau dicatat.
- **Input suara** — SpeechRecognizer bahasa Indonesia.
- **Data tahan uninstall** — JSON di folder pilihanmu via SAF (picker Android). Pilih folder Google Drive agar isinya sinkron ke cloud dan bisa dibaca dari laptop (beda jaringan tidak masalah). Ekspor CSV juga ada.
- **Widget homescreen** — total pengeluaran hari ini + shortcut buka Saku.
- **Onboarding jujur** — penjelasan Play Protect, "Izinkan setelan terbatas" untuk APK luar Play Store, dan Autostart untuk MIUI/HyperOS, semua dijelaskan di langkah pertama.

## Build

CI: setiap push ke `flutter-rewrite`/`main`, GitHub Actions menjalankan `flutter test` → `flutter analyze` → `flutter build apk --release`, lalu commit `apk/Saku-1.1.0-release.apk` ke repo + artifact `Saku-Flutter-APK`. Push tag `v*` untuk bikin GitHub Release.

Lokal: Flutter stable + JDK 17, lalu `flutter build apk --release`.

## Keystore

`android/app/zwart-money-agent.jks` (alias `zwartmoney`, password `zwartmoney2026`) — sama dengan v1.0 supaya update tetap bisa dipasang tanpa uninstall.

## Struktur

```
lib/
├── main.dart        entry
├── app.dart         root + tab + stream notifikasi
├── tabs.dart        Dasbor / Agent / Konfirmasi / Setelan
├── onboarding.dart  4 langkah setup + whitelist app
├── quick_add.dart   catat cepat (teks/suara) + konfirmasi scan struk
├── agent.dart       NLU multi-item (offline)
├── models.dart      Expense/Pending/CardDef + JSON
├── store.dart       repo + prefs
├── saku_channel.dart jembatan native
├── ocr.dart         ML Kit struk
├── voice.dart       speech_to_text
├── charts.dart      bar/line/pie CustomPainter
└── mascot.dart      mascot Saku (CustomPaint)

android/app/src/main/kotlin/id/zwart/saku/
├── MainActivity.kt              channel: SAF folder, list app, widget, notif stream
├── SakuNotificationListener.kt  NotificationListenerService → EventChannel
└── SakuWidgetProvider.kt        widget homescreen
```
