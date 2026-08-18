#ifndef Arch
  #error "Arch define wajib diisi"
#endif
#ifndef SourceDir
  #error "SourceDir define wajib diisi"
#endif
#ifndef OutputDir
  #error "OutputDir define wajib diisi"
#endif
#ifndef Version
  #error "Version define wajib diisi"
#endif

; ============================================================================
; XyDesk Installer — Wizard utuh Windows
; Driver VDD: ge9/IddSampleDriver (MIT + CC0)
; License tampilan: LICENSE (XyDesk), license-ge9.txt (driver)
;
; Build:
;   ISCC /DArch=x64 /DVersion=1.7.0 /DSourceDir=... /DOutputDir=... XyDesk.iss
;
; Lint tanpa output (dipakai job CI `installer-lint`):
;   ISCC /O- ...
; ============================================================================

[Setup]
AppId={{9F3DEB68-65B5-48C9-A92D-5A3E7B2CB304}
AppName=XyDesk
AppVersion={#Version}
AppPublisher=XySpace Tch
AppPublisherURL=https://app.xystudio.my.id
AppSupportURL=https://github.com/xykalnotkel/XyDesk/issues
AppUpdatesURL=https://github.com/xykalnotkel/XyDesk/releases
AppCopyright=Copyright (C) 2024-2026 XySpace Tch
DefaultDirName={autopf}\XyDesk
DefaultGroupName=XyDesk
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=XyDesk-{#Arch}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=120
SetupIconFile={#SourcePath}\xydesk.ico
UninstallDisplayIcon={app}\xydesk.exe
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
CloseApplications=yes
RestartApplications=no
AllowNoIcons=yes
ShowLanguageDialog=no
DisableWelcomePage=no
LicenseFile={#SourcePath}\..\..\LICENSE
InfoAfterFile={#SourcePath}\README-postinstall.md
UninstallDisplayName=XyDesk (Uninstall)

; Code signing SENGAJA tidak diaktifkan.
; Untuk mengaktifkan: daftarkan SignTool bernama "xydesk" di mesin build
; (Inno Setup IDE → Tools → Configure Sign Tools) lalu compile dengan
;   ISCC /DSign=1 ...
; Tanpa registrasi itu, direktif SignTool membuat compile GAGAL.
#ifdef Sign
SignTool=xydesk $f
SignedUninstaller=yes
#endif

#if Arch == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif

[Languages]
; Inno Setup TIDAK memaketkan Indonesian.isl (bukan terjemahan resmi).
; Merujuk compiler:Languages\Indonesian.isl membuat compile gagal di mesin
; bersih. Teks kustom Indonesia ada di [Messages] & [CustomMessages] bawah.
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; \
  Description: "Buat shortcut di Desktop"; \
  GroupDescription: "Shortcut tambahan:"; \
  Flags: unchecked
Name: "vddinstall"; \
  Description: "Pasang driver display virtual (untuk PC tanpa monitor, +FPS optimal)"; \
  GroupDescription: "Driver tambahan:"; \
  Flags: unchecked; \
  Check: VddAvailable
Name: "quicklaunch"; \
  Description: "Jalankan XyDesk saat Windows startup"; \
  GroupDescription: "Perilaku startup:"; \
  Flags: unchecked
; Tanpa flag = tercentang secara default. Flag "checked" TIDAK ADA di [Tasks]
; dan membuat compile gagal.
Name: "launchapp"; \
  Description: "Buka XyDesk setelah instalasi selesai"; \
  GroupDescription: "Setelah instalasi:"

[Files]
; Aplikasi utama (client + engine Host) — selalu dipasang.
Source: "{#SourceDir}\*"; \
  DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; \
  Excludes: "drivers\*"

; Driver VDD — hanya disalin kalau user mencentang tugas vddinstall.
; `skipifsourcedoesntexist` penting: unduhan VDD di CI bersifat best-effort,
; installer harus tetap bisa dibangun walau folder driver tidak ada.
Source: "{#SourceDir}\drivers\IddSampleDriver\*"; \
  DestDir: "{app}\drivers\IddSampleDriver"; \
  Flags: recursesubdirs createallsubdirs skipifsourcedoesntexist; \
  Tasks: vddinstall

Source: "{#SourceDir}\drivers\license-ge9.txt"; \
  DestDir: "{app}\drivers"; \
  Flags: onlyifdoesntexist skipifsourcedoesntexist; \
  Tasks: vddinstall

Source: "{#SourceDir}\drivers\README-VDD.txt"; \
  DestDir: "{app}\drivers"; \
  Flags: onlyifdoesntexist skipifsourcedoesntexist; \
  Tasks: vddinstall

[Icons]
Name: "{autoprograms}\XyDesk"; Filename: "{app}\xydesk.exe"
Name: "{autoprograms}\XyDesk\Uninstall XyDesk"; Filename: "{uninstallexe}"
Name: "{group}\{cm:UninstallProgram,XyDesk}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\XyDesk"; Filename: "{app}\xydesk.exe"; Tasks: desktopicon
; Autostart lewat registry Run milik MESIN, bukan shortcut {userstartup}.
; Installer berjalan sebagai admin, jadi menulis ke area per-user akan mendarat
; di profil admin — bukan profil user yang memakai XyDesk.
; Lihat [Registry]. Konstanta "{autostart}" tidak ada di Inno Setup.

[Registry]
; Autostart untuk semua user (installer admin). Dihapus otomatis saat uninstall.
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; \
  ValueType: string; ValueName: "XyDesk"; \
  ValueData: """{app}\xydesk.exe"""; \
  Flags: uninsdeletevalue; \
  Tasks: quicklaunch

[Run]
Filename: "{app}\drivers\IddSampleDriver\install.bat"; \
  Parameters: "/silent"; \
  StatusMsg: "Memasang driver display virtual (mungkin butuh restart)..."; \
  Flags: runhidden waituntilterminated; \
  Tasks: vddinstall; \
  Check: VddFilesInstalled

Filename: "{app}\xydesk.exe"; \
  Description: "Buka XyDesk"; \
  Flags: nowait postinstall skipifsilent; \
  Tasks: launchapp

[UninstallRun]
; Hapus driver VDD dulu sebelum file dihapus.
Filename: "{app}\drivers\IddSampleDriver\uninstall.bat"; \
  Parameters: "/silent"; \
  Flags: runhidden waituntilterminated; \
  RunOnceId: "vdduninstall"

[Messages]
BeveledLabel=XyDesk by XySpace Tch
SetupWindowTitle=XyDesk Setup (versi {#Version})
WelcomeLabel2=Ini akan memasang XyDesk versi {#Version} di komputer kamu.%n%nDisarankan menutup aplikasi lain sebelum melanjutkan.
FinishedHeadingLabel=Instalasi XyDesk selesai
ClickFinish=Klik Finish untuk menutup Setup.

[Code]
var
  VddInstallFailed: Boolean;

// Apakah berkas driver VDD ikut dipaketkan di installer ini?
//
// Unduhan VDD di CI best-effort: kalau upstream down, installer tetap terbit
// tanpa driver. Tanpa cek ini, task VDD akan tampil, user mencentangnya, lalu
// [Run] gagal memanggil install.bat yang tidak pernah ada.
function VddAvailable: Boolean;
begin
  Result := FileExists(ExpandConstant('{src}\drivers\IddSampleDriver\install.bat'));
end;

// Setelah file disalin: pastikan install.bat memang mendarat di {app}.
function VddFilesInstalled: Boolean;
begin
  Result := FileExists(ExpandConstant('{app}\drivers\IddSampleDriver\install.bat'));
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpSelectTasks then
    WizardForm.TasksList.Height := WizardForm.TasksList.Height + ScaleY(40);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssInstall then
    WizardForm.StatusLabel.Caption :=
      'Menyalin file XyDesk ke ' + ExpandConstant('{app}') + '...';

  // Exit code install.bat DIPERIKSA. Sebelumnya [Run] mengabaikannya diam-diam
  // sehingga driver gagal pasang tetap tampak "berhasil" bagi user.
  //   0 = sukses, 2 = sudah terpasang, 1/3 = gagal
  if CurStep = ssPostInstall then
  begin
    VddInstallFailed := False;
    if WizardIsTaskSelected('vddinstall') and VddFilesInstalled then
    begin
      WizardForm.StatusLabel.Caption := 'Menginstal driver display virtual...';
      if Exec(ExpandConstant('{app}\drivers\IddSampleDriver\install.bat'),
              '/silent', ExpandConstant('{app}\drivers\IddSampleDriver'),
              SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      begin
        if (ResultCode <> 0) and (ResultCode <> 2) then
          VddInstallFailed := True;
      end
      else
        VddInstallFailed := True;

      if VddInstallFailed then
        MsgBox('Driver display virtual gagal dipasang (kode ' +
               IntToStr(ResultCode) + ').' + #13#10#13#10 +
               'XyDesk tetap berfungsi normal dengan monitor fisik. ' +
               'Untuk PC tanpa monitor, pasang driver manual lewat ' +
               'Device Manager — lihat drivers\README-VDD.txt.',
               mbError, MB_OK);
    end
    else
      WizardForm.StatusLabel.Caption := 'Menyelesaikan instalasi...';
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
    UninstallProgressForm.StatusLabel.Caption := 'Membersihkan instalasi XyDesk...';
end;

// Restart hanya diminta kalau driver BENAR-BENAR terpasang.
function NeedRestart: Boolean;
begin
  Result := WizardIsTaskSelected('vddinstall') and (not VddInstallFailed) and VddFilesInstalled;
end;
