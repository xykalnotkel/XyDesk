# XyDesk update notifications

XyDesk uses `onesignal_flutter` 5.6.7 for Android/iOS push delivery. The SDK is initialized only on those platforms and does **not** request notification permission at first launch. Users opt in deliberately from **Akun → Notifikasi pembaruan**.

## OneSignal configuration

- OneSignal App ID is a public application identifier and is compiled into the client.
- FCM V1 credentials stay in OneSignal's protected dashboard configuration.
- Never copy a Firebase Admin SDK service-account JSON/private key into this repository, an APK, or client-side build secrets.
- A direct Firebase Flutter dependency, `google-services.json`, and the Google Services Gradle plugin are not required solely for this OneSignal integration.

## Sending an update

Set the OneSignal notification title and message normally, for example:

- **Title:** `XyDesk Update!! Cek Sekarang`
- **Message:** `Versi baru tersedia. Lihat detail pembaruan di XyDesk.`

Add this exact shape under **Additional Data** (custom data):

```json
{
  "route": "app_update",
  "version": "1.1.0",
  "title": "XyDesk Update!! Cek Sekarang",
  "summary": "Versi baru tersedia dengan peningkatan stabilitas dan pengalaman sesi.",
  "notes": "[\"Peningkatan stabilitas koneksi\",\"Penyempurnaan tampilan dan performa\"]"
}
```

Routing also accepts `screen` or `type` with `app_update`, `update`, or `/app-update`. An optional OneSignal action button may use action ID `open_update`. Keep `route: app_update` as the canonical format.

Payload text is display-only. Any URL supplied in Additional Data is intentionally ignored. The internal page's download button is hardcoded to:

`https://github.com/xykalnotkel/XyDesk/releases/latest/download/XyDesk.apk`

A notification click is buffered until the root Flutter Navigator exists, then opens the internal update page. It never downloads or opens GitHub directly from the click listener.

## Rich image

Use the 2:1 JPEG master:

`design/notifications/xydesk_update_banner_1024x512.jpg`

The image is 1024×512 and below 1 MB. OneSignal's Android **Big Picture** field requires a publicly reachable HTTPS URL; a repository-local path does not work. Publish this exact JPEG to the official release assets, repository, or trusted CDN before sending the campaign, then paste that HTTPS URL into the Big Picture field. Do not use an expiring or authenticated URL.

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
