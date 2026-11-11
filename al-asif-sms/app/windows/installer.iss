; Al-Asif SMS — Windows installer (Inno Setup 6).
; Built by GitHub Actions after `flutter build windows --release`.
; Produces a professional setup: Program Files install, Start Menu +
; Desktop shortcuts with the school logo, and a proper Uninstall entry
; in Windows Settings. The school's data lives in AppData (outside the
; install folder), so uninstalling never deletes it.
; Version note: keep MyAppVersion in step with pubspec.yaml.

#define MyAppName "Al-Asif SMS"
#define MyAppVersion "1.4.7"
#define MyAppPublisher "Al-Asif Public Middle School"
#define MyAppExeName "alasif_sms.exe"

[Setup]
AppId={{F2D5BBFA-FC26-4B6D-9E3C-6E060443CDEF}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\installer-output
OutputBaseFilename=Al-Asif-SMS-Setup-v{#MyAppVersion}
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
WizardStyle=modern
WizardImageFile=installer-images\wizard.bmp
WizardSmallImageFile=installer-images\wizard-small.bmp
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
