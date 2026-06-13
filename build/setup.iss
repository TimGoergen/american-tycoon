; Inno Setup 6 script for American Tycoon.
;
; Called by build.bat locally and by the windows-installer job in build.yml.
; Parameters are passed via /D on the command line:
;
;   AppVersion     — version string, e.g. "0.0.0.0042"
;   SourceExe      — full path to the Godot-exported .exe (single file, embed_pck=true)
;   OutputDir      — directory where the installer .exe will be written
;   OutputFilename — installer filename without extension

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceExe
  #error SourceExe must be defined (path to the Godot-exported game .exe)
#endif
#ifndef OutputDir
  #define OutputDir "..\dist"
#endif
#ifndef OutputFilename
  #define OutputFilename "american_tycoon_setup"
#endif

#define AppName      "American Tycoon"
#define AppPublisher "Tim Goergen"
#define AppURL       "https://github.com/TimGoergen/american-tycoon"
#define AppExeName   "american_tycoon.exe"

[Setup]
; AppId is a stable GUID that Windows uses for uninstall/update tracking.
; Do not change this after the game ships.
AppId={{A7A502EA-1CAA-435B-A021-374002D757B6}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
; PrivilegesRequired=lowest installs to the user's local Programs folder without needing admin
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
OutputDir={#OutputDir}
OutputBaseFilename={#OutputFilename}
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The game is a single self-contained .exe (Godot export_presets.cfg: binary_format/embed_pck=true)
Source: "{#SourceExe}"; DestDir: "{app}"; DestName: "{#AppExeName}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}";                          Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}";    Filename: "{uninstallexe}"
Name: "{commondesktop}\{#AppName}";                  Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
