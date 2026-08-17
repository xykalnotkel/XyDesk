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

[Setup]
AppId={{9F3DEB68-65B5-48C9-A92D-5A3E7B2CB304}
AppName=XyDesk
AppVersion={#Version}
AppPublisher=XySpace Tch
AppPublisherURL=https://app.xystudio.my.id
DefaultDirName={autopf}\XyDesk
DefaultGroupName=XyDesk
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=XyDesk-Windows-{#Arch}-Setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupIconFile={#SourcePath}\xydesk.ico
UninstallDisplayIcon={app}\xydesk.exe
PrivilegesRequired=admin
CloseApplications=yes
RestartApplications=no

#if Arch == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\XyDesk"; Filename: "{app}\xydesk.exe"
Name: "{autodesktop}\XyDesk"; Filename: "{app}\xydesk.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Buat shortcut di Desktop"; GroupDescription: "Shortcut tambahan:"

[Run]
Filename: "{app}\xydesk.exe"; Description: "Buka XyDesk"; Flags: nowait postinstall skipifsilent
