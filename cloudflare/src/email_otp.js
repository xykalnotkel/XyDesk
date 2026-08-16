// Template email OTP XyDesk — HTML + plain-text.
//
// Desain: card ungu metalik, dukung dark mode (prefers-color-scheme untuk
// Apple Mail/Samsung Mail, [data-ogsc]/[data-ogsb] untuk Outlook app).
// Gradient & text-shadow tidak dirender Outlook desktop — degrade halus.
//
// Template ini interpolasi murni di server (bukan Handlebars — Resend API
// dengan `html` mentah tidak memproses {{...}}).

/** Escape untuk konteks HTML (email = input tak tepercaya secara umum). */
function esc(s) {
  return String(s)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

/**
 * Versi plain-text — wajib ada: menurunkan skor spam & dipakai
 * preview/notifikasi sebagian client.
 */
export function otpEmailText({ otp, validMinutes = 10 }) {
  return [
    'XyDesk — Kode verifikasi',
    '',
    `Kode OTP kamu: ${otp}`,
    '',
    `Kode berlaku ${validMinutes} menit dan hanya bisa dipakai satu kali.`,
    'Jangan bagikan kode ini ke siapa pun. Tim XyDesk tidak pernah meminta kode OTP.',
    '',
    'Jika kamu tidak meminta kode ini, abaikan email ini dan segera ubah password kamu.',
    '',
    '© 2026 XyDesk — email otomatis, mohon tidak membalas.',
  ].join('\n');
}

/**
 * HTML email OTP.
 * @param {object} p
 * @param {string} p.otp         Kode 6 digit.
 * @param {number} [p.validMinutes=10]
 * @param {string} [p.name]      Nama panggilan (opsional).
 */
export function otpEmailHtml({ otp, validMinutes = 10, name }) {
  const otpSafe = esc(otp);
  const mins = esc(validMinutes);
  const greet = name ? `Halo, ${esc(name)}!` : 'Halo!';
  return `<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light dark">
  <meta name="supported-color-schemes" content="light dark">
  <title>XyDesk — Kode OTP</title>
  <style>
    :root { color-scheme: light dark; supported-color-schemes: light dark; }
    @media (prefers-color-scheme: dark) {
      .wrapper   { background-color: #14101f !important; }
      .card, .body-cell { background-color: #1d1730 !important; }
      .greeting  { color: #ede9fe !important; }
      .body-text { color: #b7a9e0 !important; }
      .strong    { color: #c4b5fd !important; }
      .otp-inner { background-color: #241a3d !important; }
      .otp-code  { color: #e9d5ff !important; text-shadow: 0 0 18px rgba(167,139,250,0.8) !important; }
      .info-box  { background-image: linear-gradient(180deg,#31255a 0%,#241a3d 100%) !important; border-color: #4c3a80 !important; }
      .info-text { color: #d6c9f2 !important; }
      .security-note { background-color: #3a2433 !important; }
      .security-text { color: #f0c9b8 !important; }
      .muted, .hint  { color: #8f82b8 !important; }
      .footer    { background-color: #161024 !important; border-top-color: #2d2350 !important; }
      .footer-text { color: #6f6399 !important; }
    }
    [data-ogsc] .wrapper, [data-ogsb] .wrapper { background-color: #14101f !important; }
    [data-ogsc] .card, [data-ogsb] .card,
    [data-ogsc] .body-cell, [data-ogsb] .body-cell { background-color: #1d1730 !important; }
    [data-ogsc] .greeting, [data-ogsb] .greeting { color: #ede9fe !important; }
    [data-ogsc] .body-text, [data-ogsb] .body-text { color: #b7a9e0 !important; }
    [data-ogsc] .strong, [data-ogsb] .strong { color: #c4b5fd !important; }
    [data-ogsc] .otp-inner, [data-ogsb] .otp-inner { background-color: #241a3d !important; }
    [data-ogsc] .otp-code, [data-ogsb] .otp-code { color: #e9d5ff !important; text-shadow: 0 0 18px rgba(167,139,250,0.8) !important; }
    [data-ogsc] .info-box, [data-ogsb] .info-box { background-image: linear-gradient(180deg,#31255a 0%,#241a3d 100%) !important; border-color: #4c3a80 !important; }
    [data-ogsc] .info-text, [data-ogsb] .info-text { color: #d6c9f2 !important; }
    [data-ogsc] .security-note, [data-ogsb] .security-note { background-color: #3a2433 !important; }
    [data-ogsc] .security-text, [data-ogsb] .security-text { color: #f0c9b8 !important; }
    [data-ogsc] .muted, [data-ogsb] .muted,
    [data-ogsc] .hint, [data-ogsb] .hint { color: #8f82b8 !important; }
    [data-ogsc] .footer, [data-ogsb] .footer { background-color: #161024 !important; border-top-color: #2d2350 !important; }
    [data-ogsc] .footer-text, [data-ogsb] .footer-text { color: #6f6399 !important; }
  </style>
</head>
<body style="margin:0; padding:0; font-family:Arial, Helvetica, sans-serif;">

  <div style="display:none; max-height:0; overflow:hidden; mso-hide:all; font-size:1px; line-height:1px; color:#ffffff; opacity:0;">
    Gunakan kode ini untuk masuk ke akun XyDesk kamu. Berlaku ${mins} menit.
  </div>

  <table class="wrapper" role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f1ecfb; padding:40px 16px;">
    <tr>
      <td align="center">

        <table class="card" role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px; width:100%; background-color:#ffffff;">

          <tr>
            <td style="height:8px; font-size:0; line-height:0; background-color:#8b5cf6; background-image:linear-gradient(90deg, #3b2d6b 0%, #a78bfa 30%, #e9d5ff 50%, #8b5cf6 70%, #3b2d6b 100%);">&nbsp;</td>
          </tr>

          <tr>
            <td style="background-color:#4c1d95; background-image:linear-gradient(135deg, #2a1f4d 0%, #4c1d95 45%, #6d28d9 75%, #8b5cf6 100%); padding:30px 44px; border-bottom:1px solid rgba(0,0,0,0.2);">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="font-size:24px; font-weight:bold; color:#ffffff; letter-spacing:1px; text-shadow:0 1px 2px rgba(0,0,0,0.5);">
                    XyDesk
                  </td>
                  <td align="right" style="font-size:11px; color:#ddd6fe; letter-spacing:2px; text-transform:uppercase;">
                    Verifikasi Akun
                  </td>
                </tr>
              </table>
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-top:14px;">
                <tr>
                  <td style="height:2px; font-size:0; line-height:0; background-image:linear-gradient(90deg, rgba(255,255,255,0.9) 0%, rgba(255,255,255,0.15) 100%);">&nbsp;</td>
                </tr>
              </table>
            </td>
          </tr>

          <tr>
            <td class="body-cell" style="padding:44px; background-color:#ffffff;">
              <p class="greeting" style="margin:0 0 10px 0; font-size:18px; color:#1e1b2e; font-weight:bold;">
                ${greet}
              </p>
              <p class="body-text" style="margin:0 0 28px 0; font-size:14px; line-height:1.7; color:#4b4468;">
                Kamu baru saja meminta kode verifikasi untuk masuk ke akun <strong class="strong" style="color:#6d28d9;">XyDesk</strong> kamu.
                Masukkan kode di bawah ini untuk melanjutkan:
              </p>

              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:14px; background-color:#8b5cf6; background-image:linear-gradient(135deg, #8b5cf6 0%, #e9d5ff 25%, #6d28d9 50%, #c4b5fd 75%, #4c1d95 100%); padding:2px;">
                <tr>
                  <td class="otp-inner" style="background-color:#faf7ff; padding:26px 16px; text-align:center;">
                    <span class="otp-code" style="display:inline-block; font-family:'Courier New', Courier, monospace; font-size:42px; font-weight:bold; color:#6d28d9; letter-spacing:12px; text-indent:12px; text-shadow:0 0 14px rgba(139,92,246,0.35); -webkit-user-select:all; user-select:all;">${otpSafe}</span>
                  </td>
                </tr>
              </table>

              <p class="hint" style="margin:0 0 24px 0; font-size:12px; color:#8f86ab; text-align:center;">
                Tekan kode di atas — semua digit terpilih otomatis, lalu ketuk &ldquo;Salin / Copy&rdquo;.
              </p>

              <table class="info-box" role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px; background-color:#f6f2ff; border:1px solid #ddd6fe;">
                <tr>
                  <td style="padding:14px 18px;">
                    <span class="info-text" style="font-size:13px; color:#4b4468;">
                      Kode berlaku selama <strong class="strong" style="color:#6d28d9;">${mins} menit</strong> dan hanya bisa dipakai satu kali.
                    </span>
                  </td>
                </tr>
              </table>

              <table class="security-note" role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:8px; background-color:#fff7f2; border-left:4px solid #e58c6b;">
                <tr>
                  <td style="padding:14px 18px;">
                    <span class="security-text" style="font-size:13px; line-height:1.7; color:#8a4a2f;">
                      <strong>Jangan bagikan kode ini!</strong> Tim XyDesk tidak akan pernah meminta kode OTP kamu,
                      baik lewat email, telepon, maupun chat.
                    </span>
                  </td>
                </tr>
              </table>

              <p class="muted" style="margin:20px 0 0 0; font-size:13px; line-height:1.7; color:#7a7294;">
                Jika kamu <strong>tidak</strong> meminta kode ini, kemungkinan ada orang lain yang mencoba masuk ke akun kamu.
                Jangan beri tahu siapa pun, dan segera ubah password kamu.
              </p>
            </td>
          </tr>

          <tr>
            <td class="footer" style="background-color:#faf8ff; border-top:1px solid #ece7f7; padding:22px 44px;">
              <p class="footer-text" style="margin:0 0 4px 0; font-size:12px; color:#8f86ab;">
                &copy; 2026 XyDesk. Semua hak dilindungi.
              </p>
              <p class="footer-text" style="margin:0; font-size:12px; color:#8f86ab;">
                Email ini dikirim otomatis oleh sistem &mdash; mohon tidak membalas.
              </p>
            </td>
          </tr>

        </table>

      </td>
    </tr>
  </table>

</body>
</html>`;
}
