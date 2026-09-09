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
; XyDesk Installer — Wizard utuh Windows (Tauri Desktop + Rust Engine)
; Driver VDD: ge9/IddSampleDriver (MIT + CC0)
; Driver Audio/Mic: VB-Audio Software / VB-CABLE (Freeware)
; License tampilan: LICENSE (XyDesk), license-ge9.txt (VDD), license-vbcable.txt (Audio)
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
AppPublisherURL=https://app.xydesk.my.id
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
UninstallDisplayIcon={app}\XyDesk.exe
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

; Code signing
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
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; \
  Description: "Buat shortcut di Desktop"; \
  GroupDescription: "Shortcut tambahan:"; \
  Flags: unchecked

; Driver bawaan (Display Virtual + Audio & Mic) otomatis terpasang secara silent
Name: "driverinstall"; \
  Description: "Pasang driver display virtual & audio/mic terintegrasi (otomatis & silent)"; \
  GroupDescription: "Driver bawaan:"; \
  Check: DriversAvailable

Name: "quicklaunch"; \
  Description: "Jalankan XyDesk saat Windows startup"; \
  GroupDescription: "Perilaku startup:"; \
  Flags: unchecked

Name: "launchapp"; \
  Description: "Buka XyDesk setelah instalasi selesai"; \
  GroupDescription: "Setelah instalasi:"

[Files]
; Aplikasi utama (shell Tauri + engine Host) — selalu dipasang.
Source: "{#SourceDir}\*"; \
  DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; \
  Excludes: "drivers\*"

; Driver Display Virtual (IddSampleDriver)
Source: "{#SourceDir}\drivers\IddSampleDriver\*"; \
  DestDir: "{app}\drivers\IddSampleDriver"; \
  Flags: recursesubdirs createallsubdirs skipifsourcedoesntexist; \
  Tasks: driverinstall

Source: "{#SourceDir}\drivers\license-ge9.txt"; \
  DestDir: "{app}\drivers"; \
  Flags: onlyifdoesntexist skipifsourcedoesntexist; \
  Tasks: driverinstall

Source: "{#SourceDir}\drivers\README-VDD.txt"; \
  DestDir: "{app}\drivers"; \
  Flags: onlyifdoesntexist skipifsourcedoesntexist; \
  Tasks: driverinstall

; Driver Virtual Audio & Mic (VB-CABLE)
Source: "{#SourceDir}\drivers\audio\*"; \
  DestDir: "{app}\drivers\audio"; \
  Flags: recursesubdirs createallsubdirs skipifsourcedoesntexist; \
  Tasks: driverinstall

[Icons]
Name: "{autoprograms}\XyDesk"; Filename: "{app}\XyDesk.exe"
Name: "{autodesktop}\XyDesk"; Filename: "{app}\XyDesk.exe"; Tasks: desktopicon

[Registry]
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; \
  ValueType: string; ValueName: "XyDesk"; \
  ValueData: """{app}\XyDesk.exe"""; \
  Flags: uninsdeletevalue; \
  Tasks: quicklaunch

[Run]
Filename: "{app}\XyDesk.exe"; \
  Description: "Buka XyDesk"; \
  Flags: nowait postinstall skipifsilent; \
  Tasks: launchapp

[UninstallRun]
; Hapus driver VDD & Audio saat uninstalasi aplikasi
Filename: "{app}\drivers\IddSampleDriver\uninstall.bat"; \
  Parameters: "/silent"; \
  Flags: runhidden waituntilterminated; \
  RunOnceId: "vdduninstall"

Filename: "{app}\drivers\audio\uninstall-audio.bat"; \
  Parameters: ""; \
  Flags: runhidden waituntilterminated; \
  RunOnceId: "audiouninstall"

[Messages]
BeveledLabel=XyDesk by XySpace Tch
SetupWindowTitle=XyDesk Setup (versi {#Version})
WelcomeLabel2=Ini akan memasang XyDesk versi {#Version} di komputer kamu.%n%nDisarankan menutup aplikasi lain sebelum melanjutkan.
FinishedHeadingLabel=Instalasi XyDesk selesai
ClickFinish=Klik Finish untuk menutup Setup.

[Code]
var
  VddInstallFailed: Boolean;

function DriversAvailable: Boolean;
begin
  Result := FileExists(ExpandConstant('{src}\drivers\IddSampleDriver\install.bat')) or
            FileExists(ExpandConstant('{src}\drivers\audio\install-audio.bat'));
end;

function VddFilesInstalled: Boolean;
begin
  Result := FileExists(ExpandConstant('{app}\drivers\IddSampleDriver\install.bat'));
end;

function AudioFilesInstalled: Boolean;
begin
  Result := FileExists(ExpandConstant('{app}\drivers\audio\install-audio.bat'));
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

  if CurStep = ssPostInstall then
  begin
    VddInstallFailed := False;
    if WizardIsTaskSelected('driverinstall') then
    begin
      // 1. Install driver display virtual bila berkas tersedia
      if VddFilesInstalled then
      begin
        WizardForm.StatusLabel.Caption := 'Menginstal driver display virtual (silent)...';
        if Exec(ExpandConstant('{app}\drivers\IddSampleDriver\install.bat'),
                '/silent', ExpandConstant('{app}\drivers\IddSampleDriver'),
                SW_HIDE, ewWaitUntilTerminated, ResultCode) then
        begin
          if (ResultCode <> 0) and (ResultCode <> 2) then
            VddInstallFailed := True;
        end
        else
          VddInstallFailed := True;
      end;

      // 2. Install driver audio & virtual mic bila berkas tersedia
      if AudioFilesInstalled then
      begin
        WizardForm.StatusLabel.Caption := 'Menginstal driver virtual audio & mic (silent)...';
        Exec(ExpandConstant('{app}\drivers\audio\install-audio.bat'),
             '', ExpandConstant('{app}\drivers\audio'),
             SW_HIDE, ewWaitUntilTerminated, ResultCode);
      end;
    end;
    WizardForm.StatusLabel.Caption := 'Menyelesaikan instalasi...';
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
    UninstallProgressForm.StatusLabel.Caption := 'Membersihkan instalasi XyDesk dan driver...';
end;

function NeedRestart: Boolean;
begin
  Result := False;
end;
