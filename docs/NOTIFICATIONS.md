# XyDesk update notifications

XyDesk uses `onesignal_flutter` 5.6.7 for Android/iOS push delivery. The SDK is initialized only on those platforms and does **not** request notification permission at first launch. Users opt in deliberately from **Akun → Notifikasi pembaruan**.

## OneSignal configuration

- OneSignal App ID is a public application identifier and is compiled into the client.
- FCM V1 credentials stay in OneSignal's protected dashboard configuration.
- Never copy a Firebase Admin SDK service-account JSON/private key into this repository, an APK, or client-side build secrets.
- A direct Firebase Flutter dependency, `google-services.json`, and the Google Services Gradle plugin are not required solely for this OneSignal integration.

## Sending an update

Push update produksi dibuat otomatis oleh `.github/workflows/release.yml` setelah
Build sukses dan seluruh aset GitHub Release, termasuk `XyDesk.apk` dan
`update.json`, selesai dipublikasikan. Workflow memakai GitHub Actions Secret
`ONESIGNAL_REST_API_KEY`; nilainya tidak boleh disimpan di source atau log.

Payload otomatis memakai bentuk berikut dan membatasi penerima Android pada
`app_version < <build baru>`:

```json
{
  "route": "app_update",
  "version": "1.1.0",
  "build": "3",
  "title": "XyDesk Update!! Cek Sekarang",
  "summary": "Versi 1.1.0 sudah tersedia untuk diunduh dan dipasang.",
  "notes": [
    "Penyempurnaan pengalaman dan stabilitas XyDesk.",
    "APK resmi diverifikasi sebelum pemasangan."
  ]
}
```

Routing juga menerima `screen` atau `type` dengan nilai `app_update`, `update`,
atau `/app-update`. Tombol aksi opsional boleh memakai ID `open_update`.
Pertahankan `route: app_update` sebagai format kanonis.

Teks payload hanya untuk tampilan. URL apa pun di Additional Data selalu
diabaikan. Halaman internal mengambil manifest
`releases/latest/download/update.json`, memvalidasi bahwa URL APK tepat mengarah
ke aset tag resmi, lalu membandingkan build terpasang dengan build Release.
Download Android hanya dimulai melalui `DownloadManager` native. Sebelum tombol
“Pasang update” aktif, aplikasi memeriksa ukuran, SHA-256, package ID, nomor
build, dan sertifikat signing.

Klik notifikasi ditahan sampai root Flutter Navigator tersedia, lalu membuka
halaman update internal. Listener tidak langsung mengunduh APK atau membuka
GitHub.

## Rich image

Use the 2:1 JPEG master:

`design/notifications/xydesk_update_banner_1024x512.jpg`

The image is 1024×512 and below 1 MB. OneSignal's Android **Big Picture** field requires a publicly reachable HTTPS URL; a repository-local path does not work. The Release workflow publishes this exact JPEG as a stable release asset and sets that public HTTPS URL in the automatic OneSignal request. Do not replace it with an expiring or authenticated URL.

The same image is bundled at `assets/img/xydesk_update_banner.jpg` for the internal page. Android's system notification remains static; motion/depth is simulated by the artwork, while the internal page adds subtle motion.

## Android icons

The default monochrome small icon is named `ic_stat_onesignal_default.png` at every required density:

| Density | Size |
| --- | ---: |
| mdpi | 24×24 |
| hdpi | 36×36 |
| xhdpi | 48×48 |
| xxhdpi | 72×72 |
| xxxhdpi | 96×96 |

The optional color large icon is `drawable-xxxhdpi/ic_onesignal_large_icon_default.png` at 256×256. Both are derived from the XyDesk launcher mark. The small icon is white-with-alpha as required by Android status-bar rendering.

## Future custom voice sound

Intended phrase: **“XyDesk Update! Cek sekarang.”**

Do not create or send a custom Android notification channel until the final user recording exists. Android 8+ persists a channel's sound choice after creation, so the recording must first be bundled under `android/app/src/main/res/raw/` using a lowercase resource name.

Reserved first version:

- channel ID: `xydesk_updates_voice_v1`
- sound resource: `xydesk_update_voice_v1`

After the recording is bundled, configure a OneSignal Android channel with that ID and sound resource. Replacing the recording later requires a new versioned channel ID, such as `xydesk_updates_voice_v2`; changing only the file is not reliable for already-created channels.
