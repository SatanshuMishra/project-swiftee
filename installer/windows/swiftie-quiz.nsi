Unicode true
ManifestDPIAware true
ManifestDPIAwareness PerMonitorV2
SetCompressor /SOLID lzma
!ifndef SOURCE_DIR
  !error "Pass /DSOURCE_DIR=<Flutter Windows release folder>"
!endif
!ifndef VERSION
  !error "Pass /DVERSION=<x.y.z>"
!endif
!define /ifndef EDITION "open"
!if "${EDITION}" == "ana"
  !define /ifndef OUTFILE "Project Swiftie_${VERSION}_x64-setup.exe"
!else
  !define /ifndef OUTFILE "Project Swiftie Open_${VERSION}_x64-setup.exe"
!endif
!include MUI2.nsh
!include FileFunc.nsh
!include WordFunc.nsh
!include LogicLib.nsh
!include x64.nsh
!include nsDialogs.nsh
!include "Win\COM.nsh"
!define MANUFACTURER "swiftiequiz"
!define PRODUCTNAME "Swiftie Quiz"
!define DISPLAYNAME "Project Swiftie"
!define MAINBINARYNAME "swiftie-quiz"
!define BUNDLEID "com.swiftiequiz.desktop"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCTNAME}"
!define MANUKEY "Software\${MANUFACTURER}"
!define MANUPRODUCTKEY "${MANUKEY}\${PRODUCTNAME}"
!define /ifndef INSTALLERICON "..\..\windows\runner\resources\app_icon.ico"
!define REPLACEDMARK ".replaced-"
!define CLOSEWAITSTEPS "20"
Var PassiveMode
Var AppStillRunning
Var ReplacedStamp
Var LockedFile
Var UpdateMode
Var NoShortcutMode
Var DeleteAppDataCheckbox
Var DeleteAppDataCheckboxState
Name "${DISPLAYNAME}"
OutFile "${OUTFILE}"
InstallDir "$LOCALAPPDATA\${PRODUCTNAME}"
InstallDirRegKey HKCU "${UNINSTKEY}" "InstallLocation"
RequestExecutionLevel user
VIProductVersion "${VERSION}.0"
VIAddVersionKey /LANG=1033 "ProductName" "${DISPLAYNAME}"
VIAddVersionKey /LANG=1033 "FileDescription" "${DISPLAYNAME}"
VIAddVersionKey /LANG=1033 "LegalCopyright" ""
VIAddVersionKey /LANG=1033 "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=1033 "ProductVersion" "${VERSION}"
!define MUI_ICON "${INSTALLERICON}"
!define MUI_LANGDLL_REGISTRY_ROOT "HKCU"
!define MUI_LANGDLL_REGISTRY_KEY "${MANUPRODUCTKEY}"
!define MUI_LANGDLL_REGISTRY_VALUENAME "Installer Language"
!define MUI_PAGE_CUSTOMFUNCTION_PRE SkipIfPassive
!insertmacro MUI_PAGE_WELCOME
!define MUI_PAGE_CUSTOMFUNCTION_PRE SkipIfPassive
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_NOAUTOCLOSE
!define MUI_FINISHPAGE_SHOWREADME
!define MUI_FINISHPAGE_SHOWREADME_TEXT "$(createDesktop)"
!define MUI_FINISHPAGE_SHOWREADME_FUNCTION CreateDesktopShortcut
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_FUNCTION RunMainBinary
!define MUI_PAGE_CUSTOMFUNCTION_PRE SkipIfPassive
!insertmacro MUI_PAGE_FINISH
!define /ifndef WS_EX_LAYOUTRTL 0x00400000
!define MUI_PAGE_CUSTOMFUNCTION_PRE un.SkipIfPassive
!define MUI_PAGE_CUSTOMFUNCTION_SHOW un.ConfirmShow
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE un.ConfirmLeave
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_RESERVEFILE_LANGDLL
LangString appRunning ${LANG_ENGLISH} "${DISPLAYNAME} is running! Please close it first then try again."
LangString appRunningOkKill ${LANG_ENGLISH} "${DISPLAYNAME} is running!$\nClick OK to kill it"
LangString failedToKillApp ${LANG_ENGLISH} "Failed to kill ${DISPLAYNAME}. Please close it first then try again"
LangString createDesktop ${LANG_ENGLISH} "Create desktop shortcut"
LangString deleteAppData ${LANG_ENGLISH} "Delete the application data"

!macro ReadModeOptions
  ${GetOptions} $CMDLINE "/P" $PassiveMode
  ${IfNot} ${Errors}
    StrCpy $PassiveMode 1
  ${EndIf}
  ${GetOptions} $CMDLINE "/UPDATE" $UpdateMode
  ${IfNot} ${Errors}
    StrCpy $UpdateMode 1
  ${EndIf}
!macroend

!macro SetUserContext
  SetShellVarContext current
  ${If} ${RunningX64}
    SetRegView 64
  ${EndIf}
!macroend

!macro FindRunningApp
  nsExec::ExecToStack `"$SYSDIR\tasklist.exe" /NH /FO CSV /FI "IMAGENAME eq ${MAINBINARYNAME}.exe" /FI "USERNAME eq $R3"`
  Pop $R0
  Pop $R1
  ClearErrors
  ${WordFind} "$R1" `"${MAINBINARYNAME}.exe"` "E+1" $R2
!macroend

!macro CloseRunningApp
  ReadEnvStr $R3 USERNAME
  StrCpy $AppStillRunning 0
  !insertmacro FindRunningApp
  ${IfNot} ${Errors}
    ${IfNot} ${Silent}
    ${AndIf} $PassiveMode <> 1
      ${If} ${Cmd} `MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION "$(appRunningOkKill)" IDCANCEL`
        Abort "$(appRunning)"
      ${EndIf}
    ${EndIf}
    nsExec::ExecToStack `"$SYSDIR\taskkill.exe" /IM ${MAINBINARYNAME}.exe /F /FI "USERNAME eq $R3"`
    Pop $R0
    Pop $R1
    StrCpy $AppStillRunning 1
    StrCpy $R4 0
    ${Do}
      Sleep 250
      IntOp $R4 $R4 + 1
      !insertmacro FindRunningApp
      ${If} ${Errors}
        StrCpy $AppStillRunning 0
        ${ExitDo}
      ${EndIf}
    ${LoopUntil} $R4 >= ${CLOSEWAITSTEPS}
  ${EndIf}
!macroend

Function MoveAside
  ClearErrors
  ${WordFind} "$R7" "${REPLACEDMARK}" "E+1" $0
  ${If} ${Errors}
    ClearErrors
    Rename "$R9" "$R9${REPLACEDMARK}$ReplacedStamp"
    ${If} ${Errors}
      StrCpy $LockedFile "$R9"
      Push "StopLocate"
      Return
    ${EndIf}
  ${EndIf}
  ClearErrors
  Push ""
FunctionEnd

Function PutBack
  StrLen $0 "${REPLACEDMARK}$ReplacedStamp"
  IntOp $0 0 - $0
  StrCpy $1 "$R9" $0
  Rename "$R9" "$1"
  ClearErrors
  Push ""
FunctionEnd

Function DeleteReplaced
  Delete "$R9"
  ClearErrors
  Push ""
FunctionEnd

Function ClearAppFiles
  ${IfNot} ${FileExists} "$INSTDIR\${MAINBINARYNAME}.exe"
    Return
  ${EndIf}
  System::Call 'kernel32::GetTickCount() i .r0'
  StrCpy $ReplacedStamp $0
  StrCpy $LockedFile ""
  ${Locate} "$INSTDIR" "/L=F /M=${MAINBINARYNAME}.exe /G=0" MoveAside
  ${If} $LockedFile == ""
    ${Locate} "$INSTDIR" "/L=F /M=*.dll /G=0" MoveAside
  ${EndIf}
  ${If} $LockedFile == ""
  ${AndIf} ${FileExists} "$INSTDIR\data\*.*"
    ${Locate} "$INSTDIR\data" "/L=F /M=*.* /G=1" MoveAside
  ${EndIf}
  ${If} $LockedFile != ""
    ${Locate} "$INSTDIR" "/L=F /M=*${REPLACEDMARK}$ReplacedStamp /G=0" PutBack
    ${If} ${FileExists} "$INSTDIR\data\*.*"
      ${Locate} "$INSTDIR\data" "/L=F /M=*${REPLACEDMARK}$ReplacedStamp /G=1" PutBack
    ${EndIf}
    Abort "$(failedToKillApp)"
  ${EndIf}
  ${Locate} "$INSTDIR" "/L=F /M=*${REPLACEDMARK}* /G=0" DeleteReplaced
  ${If} ${FileExists} "$INSTDIR\data\*.*"
    ${Locate} "$INSTDIR\data" "/L=F /M=*${REPLACEDMARK}* /G=1" DeleteReplaced
  ${EndIf}
FunctionEnd

Function .onInit
  !insertmacro ReadModeOptions
  ${GetOptions} $CMDLINE "/NS" $NoShortcutMode
  ${IfNot} ${Errors}
    StrCpy $NoShortcutMode 1
  ${EndIf}
  !insertmacro SetUserContext
FunctionEnd

Section Install
  SetOutPath $INSTDIR
  !insertmacro CloseRunningApp
  Call ClearAppFiles
  Delete "$INSTDIR\WebView2Loader.dll"
  RMDir /r "$INSTDIR\resources"
  File /r "${SOURCE_DIR}\*.*"
  WriteUninstaller "$INSTDIR\uninstall.exe"
  WriteRegStr HKCU "${MANUPRODUCTKEY}" "" $INSTDIR
  WriteRegStr HKCU "${UNINSTKEY}" "MainBinaryName" "${MAINBINARYNAME}.exe"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayName" "${DISPLAYNAME}"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayIcon" "$\"$INSTDIR\${MAINBINARYNAME}.exe$\""
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTKEY}" "Publisher" "${MANUFACTURER}"
  WriteRegStr HKCU "${UNINSTKEY}" "InstallLocation" "$\"$INSTDIR$\""
  WriteRegStr HKCU "${UNINSTKEY}" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
  WriteRegStr HKCU "${UNINSTKEY}" "QuietUninstallString" "$\"$INSTDIR\uninstall.exe$\" /S"
  WriteRegDWORD HKCU "${UNINSTKEY}" "NoModify" "1"
  WriteRegDWORD HKCU "${UNINSTKEY}" "NoRepair" "1"
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKCU "${UNINSTKEY}" "EstimatedSize" "$0"
  Call MigrateLegacyShortcuts
  Call CreateStartMenuShortcut
  ${If} $PassiveMode = 1
  ${OrIf} ${Silent}
    Call CreateDesktopShortcut
  ${EndIf}
  ${If} $PassiveMode = 1
    SetAutoClose true
  ${EndIf}
SectionEnd

Function .onInstSuccess
  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'
  ${If} $PassiveMode = 1
  ${OrIf} ${Silent}
    ${GetOptions} $CMDLINE "/R" $R0
    ${IfNot} ${Errors}
      ${GetOptions} $CMDLINE "/ARGS" $R0
      Exec `"$INSTDIR\${MAINBINARYNAME}.exe" $R0`
    ${EndIf}
  ${EndIf}
FunctionEnd

Function RunMainBinary
  Exec `"$INSTDIR\${MAINBINARYNAME}.exe"`
FunctionEnd

Function SkipIfPassive
  ${IfThen} $PassiveMode = 1 ${|} Abort ${|}
FunctionEnd

!macro MigrateLegacyShortcut folder
  ${If} ${FileExists} "${folder}\${PRODUCTNAME}.lnk"
    Delete "${folder}\${PRODUCTNAME}.lnk"
    CreateShortcut "${folder}\${DISPLAYNAME}.lnk" "$INSTDIR\${MAINBINARYNAME}.exe"
  ${EndIf}
!macroend

Function MigrateLegacyShortcuts
  !insertmacro MigrateLegacyShortcut "$SMPROGRAMS"
  !insertmacro MigrateLegacyShortcut "$DESKTOP"
FunctionEnd

Function CreateStartMenuShortcut
  ${If} $UpdateMode = 1
  ${OrIf} $NoShortcutMode = 1
    Return
  ${EndIf}
  CreateShortcut "$SMPROGRAMS\${DISPLAYNAME}.lnk" "$INSTDIR\${MAINBINARYNAME}.exe"
FunctionEnd

Function CreateDesktopShortcut
  ${If} $UpdateMode = 1
  ${OrIf} $NoShortcutMode = 1
    Return
  ${EndIf}
  CreateShortcut "$DESKTOP\${DISPLAYNAME}.lnk" "$INSTDIR\${MAINBINARYNAME}.exe"
FunctionEnd

Function un.onInit
  !insertmacro SetUserContext
  !insertmacro MUI_UNGETLANGUAGE
  !insertmacro ReadModeOptions
FunctionEnd

Function un.SkipIfPassive
  ${IfThen} $PassiveMode = 1 ${|} Abort ${|}
FunctionEnd

Function un.ConfirmShow
  FindWindow $1 "#32770" "" $HWNDPARENT
  System::Call "user32::GetDpiForWindow(p r1) i .r2"
  ${If} $(^RTL) = 1
    StrCpy $3 "${__NSD_CheckBox_EXSTYLE} | ${WS_EX_LAYOUTRTL}"
    IntOp $4 50 * $2
  ${Else}
    StrCpy $3 "${__NSD_CheckBox_EXSTYLE}"
    IntOp $4 0 * $2
  ${EndIf}
  IntOp $5 100 * $2
  IntOp $6 400 * $2
  IntOp $7 25 * $2
  IntOp $4 $4 / 96
  IntOp $5 $5 / 96
  IntOp $6 $6 / 96
  IntOp $7 $7 / 96
  System::Call 'user32::CreateWindowEx(i r3, w "${__NSD_CheckBox_CLASS}", w "$(deleteAppData)", i ${__NSD_CheckBox_STYLE}, i r4, i r5, i r6, i r7, p r1, i0, i0, i0) i .s'
  Pop $DeleteAppDataCheckbox
  SendMessage $HWNDPARENT ${WM_GETFONT} 0 0 $1
  SendMessage $DeleteAppDataCheckbox ${WM_SETFONT} $1 1
FunctionEnd

Function un.ConfirmLeave
  SendMessage $DeleteAppDataCheckbox ${BM_GETCHECK} 0 0 $DeleteAppDataCheckboxState
FunctionEnd

Function un.ShortcutTargetsApp
  Exch $R0
  Push $0
  Push $1
  Push $2
  StrCpy $2 ""
  ${If} ${FileExists} "$R0"
    !insertmacro ComHlpr_CreateInProcInstance ${CLSID_ShellLink} ${IID_IShellLink} r0 ""
    ${If} $0 P<> 0
      ${IUnknown::QueryInterface} $0 '("${IID_IPersistFile}",.r1)'
      ${If} $1 P<> 0
        ${IPersistFile::Load} $1 '("$R0",${STGM_READ})'
        ${IShellLink::GetPath} $0 '(.r2,${NSIS_MAX_STRLEN},0,0)'
        ${IUnknown::Release} $1 ""
      ${EndIf}
      ${IUnknown::Release} $0 ""
    ${EndIf}
  ${EndIf}
  ${If} $2 == "$INSTDIR\${MAINBINARYNAME}.exe"
    StrCpy $R0 1
  ${Else}
    StrCpy $R0 0
  ${EndIf}
  Pop $2
  Pop $1
  Pop $0
  Exch $R0
FunctionEnd

!macro DeleteShortcutToApp shortcut
  Push "${shortcut}"
  Call un.ShortcutTargetsApp
  Pop $0
  ${If} $0 = 1
    Delete "${shortcut}"
  ${EndIf}
!macroend

Section Uninstall
  !insertmacro CloseRunningApp
  ${If} $AppStillRunning = 1
    Abort "$(failedToKillApp)"
  ${EndIf}
  Delete "$INSTDIR\${MAINBINARYNAME}.exe"
  Delete "$INSTDIR\*.dll"
  Delete "$INSTDIR\*${REPLACEDMARK}*"
  RMDir /r "$INSTDIR\data"
  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"
  ${If} $UpdateMode <> 1
    !insertmacro DeleteShortcutToApp "$SMPROGRAMS\${DISPLAYNAME}.lnk"
    !insertmacro DeleteShortcutToApp "$DESKTOP\${DISPLAYNAME}.lnk"
    !insertmacro DeleteShortcutToApp "$SMPROGRAMS\${PRODUCTNAME}.lnk"
    !insertmacro DeleteShortcutToApp "$DESKTOP\${PRODUCTNAME}.lnk"
  ${EndIf}
  DeleteRegKey HKCU "${UNINSTKEY}"
  ${If} $UpdateMode <> 1
    DeleteRegKey HKCU "${MANUPRODUCTKEY}"
    DeleteRegKey /ifempty HKCU "${MANUKEY}"
    DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "${PRODUCTNAME}"
  ${EndIf}
  ${If} $DeleteAppDataCheckboxState = 1
  ${AndIf} $UpdateMode <> 1
    SetShellVarContext current
    RMDir /r "$APPDATA\${BUNDLEID}"
    RMDir /r "$LOCALAPPDATA\${BUNDLEID}"
  ${EndIf}
  ${If} $PassiveMode = 1
  ${OrIf} $UpdateMode = 1
    SetAutoClose true
  ${EndIf}
SectionEnd
