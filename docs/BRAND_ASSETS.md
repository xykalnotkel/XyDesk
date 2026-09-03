# Third-party identity artwork

## Google multicolor G

`assets/img/google_g.png` is Google's official multicolor G asset downloaded
from the Google Identity branding guidance, rather than a locally redrawn logo.

Guidance: <https://developers.google.com/identity/branding-guidelines>

Asset: <https://developers.google.com/static/identity/images/g-logo.png>
(retrieved 2026-08-17; SHA-256
`d1ce9c2af0b10a7333abc99bc706f9a6a199e5b65bf3e3009624f076b8638e6a`)

The sign-in control keeps the mark's original colors and aspect ratio and uses
Google's light/dark button boundary colors. Do not recolor, distort, trace, or
replace this file with a custom `CustomPainter` approximation.

## XyDesk logo — satu sumber untuk semua platform

`design/logo-asli.png` is the single source of truth: a square, transparent
canvas whose artwork does not touch the edges. Every other logo file is
generated from it by `python3 tool/gen_logo.py`:

| Target | File | Note |
|---|---|---|
| Flutter app | `assets/img/logo.png` | 1024 px |
| Web | `web/public/logo.png`, `logo-white.png`, `icon-192`, `icon-512`, `apple-touch-icon`, `favicon-16/32`, `favicon.ico` | |
| Monochrome | `design/x-white.png`, `x-black.png` | silhouette for contrasting backgrounds |
| Android launcher | `mipmap-*/ic_launcher.png` (legacy, logo on dark tile) + `ic_launcher_foreground.png` (adaptive, 108 dp) | five densities |
| Android splash | `splash_logo_tight.png` (104 dp) + `splash_logo_android12.png` (inside the 2/3 masked circle) | |
| Windows | `packaging/windows/xydesk.ico` | 16–256 px |
| Desktop shell | `desktop/public/logo.png` (merek di sidebar + favicon), `desktop/electron/tray.ico` (tray, taskbar, dan `build.win.icon`) | jangan digambar ulang di JSX |

The Android splash mark fits Android 12's masked icon safe zone and matches
Flutter's centered first frame before the wordmark reveal.

To change the identity: replace `design/logo-asli.png`, then re-run the
generator. Never hand-edit a generated file — the next generator run will
overwrite it, and the app will end up showing two different logos at once.
