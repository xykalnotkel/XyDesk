// GENERATED-FRIENDLY: tambah bahasa baru lewat `tool/add_language.dart`.
//
// Sengaja memakai peta sederhana, bukan `flutter_localizations` + ARB,
// supaya menambah bahasa tidak perlu codegen dan bisa dilakukan siapa saja
// hanya dengan menyalin satu blok.

import 'package:flutter/widgets.dart';

/// Daftar bahasa yang tersedia.
class AppLang {
  const AppLang(this.code, this.name, this.nativeName, {this.rtl = false});

  final String code;
  final String name;
  final String nativeName;
  final bool rtl;

  static const id = AppLang('id', 'Indonesian', 'Indonesia');
  static const en = AppLang('en', 'English', 'English');
  static const zh = AppLang('zh', 'Chinese', '中文');
  static const es = AppLang('es', 'Spanish', 'Español');
  static const pt = AppLang('pt', 'Portuguese', 'Português');
  static const ar = AppLang('ar', 'Arabic', 'العربية', rtl: true);

  static const all = <AppLang>[id, en, zh, es, pt, ar];

  static AppLang byCode(String c) =>
      all.firstWhere((l) => l.code == c, orElse: () => en);
}

/// Semua teks aplikasi.
///
/// Kunci ditulis dalam bahasa Inggris ringkas agar mudah dicari.
/// Bila sebuah bahasa belum punya terjemahan untuk suatu kunci, sistem
/// otomatis jatuh ke bahasa Inggris — jadi tidak akan pernah kosong.
const Map<String, Map<String, String>> kStrings = {
  // ── Umum ──────────────────────────────────────────────
  'app_tagline': {
    'id': 'PC kamu, di tangan kamu',
    'en': 'Your PC, in your hand',
    'zh': '你的电脑，尽在掌握',
    'es': 'Tu PC, en tu mano',
    'pt': 'Seu PC, na sua mão',
    'ar': 'حاسوبك في يدك',
  },
  'continue_': {
    'id': 'Lanjutkan',
    'en': 'Continue',
    'zh': '继续',
    'es': 'Continuar',
    'pt': 'Continuar',
    'ar': 'متابعة',
  },
  'cancel': {
    'id': 'Batal',
    'en': 'Cancel',
    'zh': '取消',
    'es': 'Cancelar',
    'pt': 'Cancelar',
    'ar': 'إلغاء',
  },
  'back': {
    'id': 'Kembali',
    'en': 'Back',
    'zh': '返回',
    'es': 'Atrás',
    'pt': 'Voltar',
    'ar': 'رجوع',
  },
  'save': {
    'id': 'Simpan',
    'en': 'Save',
    'zh': '保存',
    'es': 'Guardar',
    'pt': 'Salvar',
    'ar': 'حفظ',
  },
  'retry': {
    'id': 'Coba lagi',
    'en': 'Retry',
    'zh': '重试',
    'es': 'Reintentar',
    'pt': 'Tentar novamente',
    'ar': 'إعادة',
  },
  'copy': {
    'id': 'Salin',
    'en': 'Copy',
    'zh': '复制',
    'es': 'Copiar',
    'pt': 'Copiar',
    'ar': 'نسخ',
  },
  'copied': {
    'id': 'Disalin',
    'en': 'Copied',
    'zh': '已复制',
    'es': 'Copiado',
    'pt': 'Copiado',
    'ar': 'تم النسخ',
  },
  'close': {
    'id': 'Tutup',
    'en': 'Close',
    'zh': '关闭',
    'es': 'Cerrar',
    'pt': 'Fechar',
    'ar': 'إغلاق',
  },

  // ── Navigasi ─────────────────────────────────────────
  'nav_home': {
    'id': 'Beranda',
    'en': 'Home',
    'zh': '主页',
    'es': 'Inicio',
    'pt': 'Início',
    'ar': 'الرئيسية',
  },
  'nav_connect': {
    'id': 'Hubungkan',
    'en': 'Connect',
    'zh': '连接',
    'es': 'Conectar',
    'pt': 'Conectar',
    'ar': 'اتصال',
  },
  'nav_control': {
    'id': 'Kontrol',
    'en': 'Control',
    'zh': '控制',
    'es': 'Control',
    'pt': 'Controle',
    'ar': 'تحكم',
  },
  'nav_account': {
    'id': 'Akun',
    'en': 'Account',
    'zh': '账户',
    'es': 'Cuenta',
    'pt': 'Conta',
    'ar': 'الحساب',
  },

  // ── Autentikasi ──────────────────────────────────────
  'auth_welcome': {
    'id': 'Selamat datang',
    'en': 'Welcome',
    'zh': '欢迎',
    'es': 'Bienvenido',
    'pt': 'Bem-vindo',
    'ar': 'مرحبا',
  },
  'auth_subtitle': {
    'id': 'Masuk untuk menyimpan perangkat dan profil kontrol kamu.',
    'en': 'Sign in to save your devices and control profiles.',
    'zh': '登录以保存您的设备和控制配置。',
    'es': 'Inicia sesión para guardar tus dispositivos y perfiles.',
    'pt': 'Entre para salvar seus dispositivos e perfis.',
    'ar': 'سجّل الدخول لحفظ أجهزتك وملفات التحكم.',
  },
  'auth_google': {
    'id': 'Lanjutkan dengan Google',
    'en': 'Continue with Google',
    'zh': '使用 Google 继续',
    'es': 'Continuar con Google',
    'pt': 'Continuar com Google',
    'ar': 'المتابعة عبر Google',
  },
  'auth_email': {
    'id': 'Lanjutkan dengan Email',
    'en': 'Continue with Email',
    'zh': '使用邮箱继续',
    'es': 'Continuar con correo',
    'pt': 'Continuar com e-mail',
    'ar': 'المتابعة بالبريد',
  },
  'auth_guest': {
    'id': 'Pakai tanpa akun',
    'en': 'Use without an account',
    'zh': '无需账户使用',
    'es': 'Usar sin cuenta',
    'pt': 'Usar sem conta',
    'ar': 'استخدام بدون حساب',
  },
  'auth_email_label': {
    'id': 'Alamat email',
    'en': 'Email address',
    'zh': '电子邮箱',
    'es': 'Correo electrónico',
    'pt': 'Endereço de e-mail',
    'ar': 'البريد الإلكتروني',
  },
  'auth_send_code': {
    'id': 'Kirim kode',
    'en': 'Send code',
    'zh': '发送验证码',
    'es': 'Enviar código',
    'pt': 'Enviar código',
    'ar': 'إرسال الرمز',
  },
  'auth_otp_title': {
    'id': 'Masukkan kode verifikasi',
    'en': 'Enter verification code',
    'zh': '输入验证码',
    'es': 'Introduce el código',
    'pt': 'Digite o código',
    'ar': 'أدخل رمز التحقق',
  },
  'auth_otp_sent': {
    'id': 'Kode 6 digit dikirim ke',
    'en': '6-digit code sent to',
    'zh': '6 位验证码已发送至',
    'es': 'Código de 6 dígitos enviado a',
    'pt': 'Código de 6 dígitos enviado para',
    'ar': 'تم إرسال رمز مكوّن من 6 أرقام إلى',
  },
  'auth_resend': {
    'id': 'Kirim ulang kode',
    'en': 'Resend code',
    'zh': '重新发送',
    'es': 'Reenviar código',
    'pt': 'Reenviar código',
    'ar': 'إعادة الإرسال',
  },
  'auth_resend_in': {
    'id': 'Kirim ulang dalam',
    'en': 'Resend in',
    'zh': '重新发送倒计时',
    'es': 'Reenviar en',
    'pt': 'Reenviar em',
    'ar': 'إعادة الإرسال خلال',
  },
  'auth_verify': {
    'id': 'Verifikasi',
    'en': 'Verify',
    'zh': '验证',
    'es': 'Verificar',
    'pt': 'Verificar',
    'ar': 'تحقق',
  },
  'auth_invalid_email': {
    'id': 'Format email tidak valid',
    'en': 'Invalid email format',
    'zh': '邮箱格式无效',
    'es': 'Formato de correo no válido',
    'pt': 'Formato de e-mail inválido',
    'ar': 'صيغة البريد غير صحيحة',
  },
  'auth_invalid_otp': {
    'id': 'Kode salah. Coba lagi.',
    'en': 'Wrong code. Try again.',
    'zh': '验证码错误，请重试。',
    'es': 'Código incorrecto.',
    'pt': 'Código incorreto.',
    'ar': 'رمز خاطئ. حاول مجددًا.',
  },
  'auth_legal': {
    'id': 'Dengan melanjutkan, kamu menyetujui',
    'en': 'By continuing, you agree to our',
    'zh': '继续即表示您同意我们的',
    'es': 'Al continuar, aceptas nuestros',
    'pt': 'Ao continuar, você concorda com',
    'ar': 'بالمتابعة، أنت توافق على',
  },
  'legal_terms': {
    'id': 'Ketentuan Layanan',
    'en': 'Terms of Service',
    'zh': '服务条款',
    'es': 'Términos del servicio',
    'pt': 'Termos de Serviço',
    'ar': 'شروط الخدمة',
  },
  'legal_privacy': {
    'id': 'Kebijakan Privasi',
    'en': 'Privacy Policy',
    'zh': '隐私政策',
    'es': 'Política de privacidad',
    'pt': 'Política de Privacidade',
    'ar': 'سياسة الخصوصية',
  },
  'legal_licenses': {
    'id': 'Lisensi sumber terbuka',
    'en': 'Open-source licenses',
    'zh': '开源许可',
    'es': 'Licencias de código abierto',
    'pt': 'Licenças de código aberto',
    'ar': 'تراخيص المصادر المفتوحة',
  },

  // ── Beranda / perangkat ──────────────────────────────
  'home_devices': {
    'id': 'Perangkat',
    'en': 'Devices',
    'zh': '设备',
    'es': 'Dispositivos',
    'pt': 'Dispositivos',
    'ar': 'الأجهزة',
  },
  'home_empty_title': {
    'id': 'Belum ada perangkat',
    'en': 'No devices yet',
    'zh': '暂无设备',
    'es': 'Aún no hay dispositivos',
    'pt': 'Nenhum dispositivo ainda',
    'ar': 'لا توجد أجهزة بعد',
  },
  'home_empty_msg': {
    'id':
        'Pasang XyDesk Host di PC kamu, lalu masukkan ID yang muncul di sana.',
    'en': 'Install XyDesk Host on your PC, then enter the ID shown there.',
    'zh': '在电脑上安装 XyDesk Host，然后输入显示的 ID。',
    'es': 'Instala XyDesk Host en tu PC e introduce el ID mostrado.',
    'pt': 'Instale o XyDesk Host no seu PC e insira o ID exibido.',
    'ar': 'ثبّت XyDesk Host على حاسوبك ثم أدخل المعرّف الظاهر.',
  },
  'status_online': {
    'id': 'Aktif',
    'en': 'Online',
    'zh': '在线',
    'es': 'En línea',
    'pt': 'Online',
    'ar': 'متصل',
  },
  'status_offline': {
    'id': 'Mati',
    'en': 'Offline',
    'zh': '离线',
    'es': 'Desconectado',
    'pt': 'Offline',
    'ar': 'غير متصل',
  },
  'device_detail': {
    'id': 'Detail perangkat',
    'en': 'Device details',
    'zh': '设备详情',
    'es': 'Detalles del dispositivo',
    'pt': 'Detalhes do dispositivo',
    'ar': 'تفاصيل الجهاز',
  },
  'device_preview': {
    'id': 'Pratinjau layar',
    'en': 'Screen preview',
    'zh': '屏幕预览',
    'es': 'Vista previa',
    'pt': 'Prévia da tela',
    'ar': 'معاينة الشاشة',
  },
  'device_connect': {
    'id': 'Hubungkan sekarang',
    'en': 'Connect now',
    'zh': '立即连接',
    'es': 'Conectar ahora',
    'pt': 'Conectar agora',
    'ar': 'اتصل الآن',
  },
  'device_rename': {
    'id': 'Ganti nama',
    'en': 'Rename',
    'zh': '重命名',
    'es': 'Renombrar',
    'pt': 'Renomear',
    'ar': 'إعادة تسمية',
  },
  'device_remove': {
    'id': 'Hapus perangkat',
    'en': 'Remove device',
    'zh': '删除设备',
    'es': 'Eliminar dispositivo',
    'pt': 'Remover dispositivo',
    'ar': 'إزالة الجهاز',
  },

  // ── Hubungkan ────────────────────────────────────────
  'connect_title': {
    'id': 'Hubungkan ke perangkat',
    'en': 'Connect to a device',
    'zh': '连接到设备',
    'es': 'Conectar a un dispositivo',
    'pt': 'Conectar a um dispositivo',
    'ar': 'الاتصال بجهاز',
  },
  'connect_subtitle': {
    'id': 'Masukkan ID dan kata sandi dari aplikasi host di PC kamu.',
    'en': 'Enter the ID and password from the host app on your PC.',
    'zh': '输入电脑主机应用中的 ID 和密码。',
    'es': 'Introduce el ID y la contraseña de la app host.',
    'pt': 'Insira o ID e a senha do app host no seu PC.',
    'ar': 'أدخل المعرّف وكلمة المرور من تطبيق المضيف.',
  },
  'connect_id': {
    'id': 'ID Perangkat',
    'en': 'Device ID',
    'zh': '设备 ID',
    'es': 'ID del dispositivo',
    'pt': 'ID do dispositivo',
    'ar': 'معرّف الجهاز',
  },
  'connect_pw': {
    'id': 'Kata sandi',
    'en': 'Password',
    'zh': '密码',
    'es': 'Contraseña',
    'pt': 'Senha',
    'ar': 'كلمة المرور',
  },
  'connect_remember': {
    'id': 'Ingat perangkat ini',
    'en': 'Remember this device',
    'zh': '记住此设备',
    'es': 'Recordar este dispositivo',
    'pt': 'Lembrar este dispositivo',
    'ar': 'تذكّر هذا الجهاز',
  },
  'connect_btn': {
    'id': 'Hubungkan',
    'en': 'Connect',
    'zh': '连接',
    'es': 'Conectar',
    'pt': 'Conectar',
    'ar': 'اتصال',
  },
  'connect_scan': {
    'id': 'Pindai QR',
    'en': 'Scan QR',
    'zh': '扫描二维码',
    'es': 'Escanear QR',
    'pt': 'Escanear QR',
    'ar': 'مسح QR',
  },
  'connect_history': {
    'id': 'Riwayat',
    'en': 'History',
    'zh': '历史',
    'es': 'Historial',
    'pt': 'Histórico',
    'ar': 'السجل',
  },
  'connect_support': {
    'id': 'Dukung kami di',
    'en': 'Support us on',
    'zh': '支持我们',
    'es': 'Apóyanos en',
    'pt': 'Apoie-nos em',
    'ar': 'ادعمنا على',
  },
  'connect_wrong_pw': {
    'id': 'Kata sandi salah. Sisa 3 percobaan.',
    'en': 'Wrong password. 3 attempts left.',
    'zh': '密码错误，剩余 3 次机会。',
    'es': 'Contraseña incorrecta. Quedan 3 intentos.',
    'pt': 'Senha incorreta. Restam 3 tentativas.',
    'ar': 'كلمة مرور خاطئة. تبقّى 3 محاولات.',
  },

  // ── Sesi ─────────────────────────────────────────────
  'session_connecting': {
    'id': 'Menghubungkan ke',
    'en': 'Connecting to',
    'zh': '正在连接',
    'es': 'Conectando a',
    'pt': 'Conectando a',
    'ar': 'جارٍ الاتصال بـ',
  },
  'session_placeholder': {
    'id': 'Layar remote akan tampil di sini',
    'en': 'Remote screen will appear here',
    'zh': '远程屏幕将显示在此处',
    'es': 'La pantalla remota aparecerá aquí',
    'pt': 'A tela remota aparecerá aqui',
    'ar': 'ستظهر الشاشة البعيدة هنا',
  },
  'session_disconnect': {
    'id': 'Putuskan sambungan',
    'en': 'Disconnect',
    'zh': '断开连接',
    'es': 'Desconectar',
    'pt': 'Desconectar',
    'ar': 'قطع الاتصال',
  },
  'session_restart': {
    'id': 'Mulai ulang',
    'en': 'Restart',
    'zh': '重启',
    'es': 'Reiniciar',
    'pt': 'Reiniciar',
    'ar': 'إعادة تشغيل',
  },

  // ── Akun & pengaturan ────────────────────────────────
  'account': {
    'id': 'Akun',
    'en': 'Account',
    'zh': '账户',
    'es': 'Cuenta',
    'pt': 'Conta',
    'ar': 'الحساب',
  },
  'settings_appearance': {
    'id': 'Tampilan',
    'en': 'Appearance',
    'zh': '外观',
    'es': 'Apariencia',
    'pt': 'Aparência',
    'ar': 'المظهر',
  },
  'settings_language': {
    'id': 'Bahasa',
    'en': 'Language',
    'zh': '语言',
    'es': 'Idioma',
    'pt': 'Idioma',
    'ar': 'اللغة',
  },
  'settings_theme_dark': {
    'id': 'Gelap',
    'en': 'Dark',
    'zh': '深色',
    'es': 'Oscuro',
    'pt': 'Escuro',
    'ar': 'داكن',
  },
  'settings_theme_light': {
    'id': 'Terang',
    'en': 'Light',
    'zh': '浅色',
    'es': 'Claro',
    'pt': 'Claro',
    'ar': 'فاتح',
  },
  'settings_theme_system': {
    'id': 'Ikuti sistem',
    'en': 'Follow system',
    'zh': '跟随系统',
    'es': 'Según el sistema',
    'pt': 'Seguir o sistema',
    'ar': 'حسب النظام',
  },
  'settings_permissions': {
    'id': 'Izin aplikasi',
    'en': 'App permissions',
    'zh': '应用权限',
    'es': 'Permisos',
    'pt': 'Permissões',
    'ar': 'أذونات التطبيق',
  },
  'settings_storage': {
    'id': 'Penyimpanan & berkas',
    'en': 'Storage & files',
    'zh': '存储与文件',
    'es': 'Almacenamiento',
    'pt': 'Armazenamento',
    'ar': 'التخزين والملفات',
  },
  'settings_about': {
    'id': 'Tentang',
    'en': 'About',
    'zh': '关于',
    'es': 'Acerca de',
    'pt': 'Sobre',
    'ar': 'حول',
  },
  'settings_devlog': {
    'id': 'Log pengembang',
    'en': 'Developer log',
    'zh': '开发者日志',
    'es': 'Registro',
    'pt': 'Log do desenvolvedor',
    'ar': 'سجل المطور',
  },
  'sign_out': {
    'id': 'Keluar',
    'en': 'Sign out',
    'zh': '退出登录',
    'es': 'Cerrar sesión',
    'pt': 'Sair',
    'ar': 'تسجيل الخروج',
  },
};

/// Akses teks terlokalisasi.
class L {
  const L(this.lang);

  final AppLang lang;

  String t(String key) {
    final m = kStrings[key];
    if (m == null) return key; // kunci tidak dikenal — tampilkan apa adanya
    return m[lang.code] ?? m['en'] ?? key;
  }

  static L of(BuildContext context) =>
      L(Localizations.of<L>(context, L)?.lang ?? AppLang.en);
}

/// Delegate agar `L` bisa diambil lewat `Localizations`.
class LDelegate extends LocalizationsDelegate<L> {
  const LDelegate(this.lang);

  final AppLang lang;

  @override
  bool isSupported(Locale locale) =>
      AppLang.all.any((l) => l.code == locale.languageCode);

  @override
  Future<L> load(Locale locale) async => L(lang);

  @override
  bool shouldReload(LDelegate old) => old.lang.code != lang.code;
}

extension LX on BuildContext {
  /// Ringkas: `context.tr('nav_home')`
  String tr(String key) => L.of(this).t(key);
}
