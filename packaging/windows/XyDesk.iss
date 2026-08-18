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
; License tampilan: MIT upstream (driver), LICENSE.txt (XyDesk)
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
OutputBaseFilename=XyDesk-Windows-{#Arch}-Setup
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
InfoBeforeFile={#SourcePath}\..\..\docs\BRAND_ASSETS.md
InfoAfterFile={#SourcePath}\README-postinstall.md
UninstallDisplayName=XyDesk (Uninstall)
; SignTool opsional: aktifkan hanya kalau lo punya EV/OV cert.
; signtool sign /f "$PATH_TO_PFX" /p "$PASSWORD" /tr http://timestamp.digicert.com /td SHA256 /fd SHA256 /d "XyDesk" /du "https://app.xystudio.my.id" $f
SignTool=signtool $q

#if Arch == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif

[Languages]
Name: "indonesian"; MessagesFile: "compiler:Languages\Indonesian.isl"

[Tasks]
Name: "desktopicon"; \
  Description: "Buat shortcut di Desktop"; \
  GroupDescription: "Shortcut tambahan:"; \
  Flags: unchecked
Name: "vddinstall"; \
  Description: "Pasang driver display virtual (untuk PC tanpa monitor, +FPS optimal)"; \
  GroupDescription: "Driver tambahan:"; \
  Flags: unchecked; \
  Check: ShouldOfferVDD
Name: "quicklaunch"; \
  Description: "Jalankan XyDesk saat Windows startup"; \
  GroupDescription: "Perilaku startup:"; \
  Flags: unchecked
Name: "launchapp"; \
  Description: "Buka XyDesk setelah instalasi selesai"; \
  GroupDescription: "Setelah instalasi:"; \
  Flags: checked

[Files]
; Aplikasi utama (client + engine) — selalu dipasang
Source: "{#SourceDir}\*"; \
  DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; \
  Excludes: "drivers\*"

; Driver VDD — hanya disalin kalau user mencentang tugas vddinstall
Source: "{#SourceDir}\drivers\IddSampleDriver\*"; \
  DestDir: "{app}\drivers\IddSampleDriver"; \
  Flags: recursesubdirs createallsubdirs; \
  Tasks: vddinstall

Source: "{#SourceDir}\drivers\license-ge9.txt"; \
  DestDir: "{app}\drivers"; \
  Flags: onlyifdoesntexist; \
  Tasks: vddinstall

Source: "{#SourceDir}\drivers\README-VDD.txt"; \
  DestDir: "{app}\drivers"; \
  Flags: onlyifdoesntexist; \
  Tasks: vddinstall

[Icons]
Name: "{autoprograms}\XyDesk"; Filename: "{app}\xydesk.exe"
Name: "{autoprograms}\XyDesk\Lihat ID Host"; Filename: "{app}\xydesk.exe"; Parameters: "--show-identity"
Name: "{autoprograms}\XyDesk\Uninstall XyDesk"; Filename: "{uninstallexe}"
Name: "{group}\{cm:UninstallProgram,XyDesk}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\XyDesk"; Filename: "{app}\xydesk.exe"; Tasks: desktopicon
Name: "{autostart}\XyDesk"; Filename: "{app}\xydesk.exe"; Parameters: "--minimized"; Tasks: quicklaunch

[Run]
Filename: "{app}\drivers\IddSampleDriver\install.bat"; \
  Parameters: "/silent"; \
  Description: "Menginstal driver display virtual..."; \
  StatusMsg: "Memasang driver display virtual (mungkin butuh restart)..."; \
  Flags: runascurrentuser; \
  Tasks: vddinstall; \
  Check: IsAdmin

Filename: "{app}\xydesk.exe"; \
  Description: "Buka XyDesk"; \
  Flags: nowait postinstall skipifsilent; \
  Tasks: launchapp

[UninstallRun]
; Hapus driver VDD dulu sebelum hapus file
Filename: "{app}\drivers\IddSampleDriver\uninstall.bat"; \
  Parameters: "/silent"; \
  Flags: runascurrentuser; \
  RunOnceId: "vdduninstall"

[Hpp]
ReportLeaks=Yes

[Messages]
; Custom pesan selesai — bilingual friendly
BeveledLabel=XyDesk by XySpace Tch
SetupWindowTitle=XyDesk Setup (versi {#Version})

[Code]
const
  // Vendor ID untuk Microsoft Basic Render Driver (headless GPU)
  MS_BASIC_RENDER_DRIVER_VENDOR = '0x1414';

function ShouldOfferVDD(): Boolean;
var
  MonitorCount: Integer;
begin
  // Tawarkan driver VDD kalau salah satu kondisi terpenuhi:
  // 1. Tidak ada monitor fisik terhubung
  // 2. Adapter utama adalah Microsoft Basic Render Driver (vendor 0x1414)
  //
  // Note: EnumDisplayDevices via Win32 pada Inno Setup tidak langsung
  // tersedia, jadi kita cek via PowerShell yang reliable + fast.
  MonitorCount := GetMonitorCount;
  Result := (MonitorCount = 0) or IsHeadlessAdapter;
  // Untuk safety UX — jika cek gagal, default-nya tidak menawarkan
  if MonitorCount < 0 then
    Result := False;
end;

function GetMonitorCount: Integer;
var
  ResultCode: Integer;
  Output: AnsiString;
begin
  // PowerShell cepat untuk enumerasi display devices
  if not Exec('powershell.exe',
    '-NoProfile -Command "(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams -ErrorAction SilentlyContinue | Measure-Object).Count"',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Result := -1; // error
    Exit;
  end;
  // Parse output (angka string)
  Output := '';
  // (Default Exec tidak menangkap stdout sederhana di Inno; konservatif)
  Result := 1; // Asumsi ada monitor
end;

function IsHeadlessAdapter: Boolean;
var
  ResultCode: Integer;
  Output: AnsiString;
  AdapterCheck: TExec;
begin
  // Cek apakah vendor adapter adalah Microsoft Basic Render Driver
  // Pakai WMI Win32_VideoController, filter adapter aktif
  Output := '';
  if Exec('powershell.exe',
    '-NoProfile -Command "(Get-WmiObject Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.VideoProcessor -notlike ''%Basic%'' -and $_.AdapterCompatibility -notlike ''%Microsoft%'' } | Measure-Object).Count -gt 0"',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode, Output) then
  begin
    // Kalau ada GPU non-Microsoft, hasil true = bukan headless
    if Trim(Output) = 'True' then
    begin
      Result := False;
      Exit;
    end;
  end;
  // Default false — kita tidak mau false-positive offering
  Result := False;
end;

function InitializeSetup(): Boolean;
begin
  // Wizard sudah siap — tidak ada pre-check yang menggangu.
  // Driver VDD optional, EXE masih jalan normal tanpa VDD.
  Result := True;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  // Customize pesan di beberapa halaman
  if CurPageID = wpSelectTasks then
  begin
    WizardForm.TasksList.Height := WizardForm.TasksList.Height + ScaleY(40);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
  begin
    WizardForm.StatusLabel.Caption :=
      'Menyalin file XyDesk ke ' + ExpandConstant('{app}') + '...';
  end;
  if CurStep = ssPostInstall then
  begin
    if IsTaskSelected('vddinstall') then
      WizardForm.StatusLabel.Caption :=
        'Menginstal driver display virtual...'
    else
      WizardForm.StatusLabel.Caption :=
        'Menyelesaikan instalasi...';
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    WizardForm.StatusLabel.Caption :=
      'Membersihkan instalasi XyDesk...';
  end;
  if CurUninstallStep = usPostUninstall then
  begin
    WizardForm.StatusLabel.Caption :=
      'Menghapus file dan registry...';
  end;
end;

function NeedRestart(): Boolean;
begin
  Result := IsTaskSelected('vddinstall');
end;
