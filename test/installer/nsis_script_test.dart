import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const scriptPath = 'installer/windows/swiftie-quiz.nsi';
const uninstallKey =
    r'Software\Microsoft\Windows\CurrentVersion\Uninstall\Swiftie Quiz';
const manufacturerKey = r'Software\swiftiequiz\Swiftie Quiz';

Map<String, String> scriptDefines(String script) => {
  for (final match in RegExp(
    r'^\s*!define\s+(?:/ifndef\s+)?(\w+)\s+"([^"]*)"\s*$',
    multiLine: true,
  ).allMatches(script))
    match.group(1)!: match.group(2)!,
};

String renderDefines(String script) {
  final defines = scriptDefines(script);
  var rendered = script;
  var previous = '';
  while (rendered != previous) {
    previous = rendered;
    rendered = rendered.replaceAllMapped(
      RegExp(r'\$\{(\w+)\}'),
      (match) => defines[match.group(1)!] ?? match.group(0)!,
    );
  }
  return rendered;
}

List<String> trimmedLines(String script) =>
    script.split('\n').map((line) => line.trim()).toList();

List<String> block(List<String> lines, String start, String end) {
  final from = lines.indexOf(start);
  expect(from, isNonNegative, reason: 'missing "$start"');
  final to = lines.indexOf(end, from);
  expect(to, greaterThan(from), reason: 'no "$end" after "$start"');
  return lines.sublist(from + 1, to);
}

List<String> macroBody(List<String> lines, String name) =>
    block(lines, '!macro $name', '!macroend');

List<String> functionBody(List<String> lines, String name) =>
    block(lines, 'Function $name', 'FunctionEnd');

List<String> sectionBody(List<String> lines, String name) =>
    block(lines, 'Section $name', 'SectionEnd');

List<String> expandMacroCall(List<String> lines, String line) {
  final call = RegExp(r'^!insertmacro (\w+)((?:\s+"[^"]*")*)$')
      .firstMatch(line);
  if (call == null) {
    return [line];
  }
  final name = call.group(1)!;
  final header = lines.indexWhere(
    (candidate) =>
        candidate == '!macro $name' || candidate.startsWith('!macro $name '),
  );
  if (header < 0) {
    return [line];
  }
  final parameters = lines[header].split(RegExp(r'\s+')).skip(2).toList();
  final arguments = [
    for (final match in RegExp(r'"([^"]*)"').allMatches(call.group(2)!))
      match.group(1)!,
  ];
  return [
    for (final bodyLine in lines.sublist(
      header + 1,
      lines.indexOf('!macroend', header),
    ))
      parameters.indexed.fold(
        bodyLine,
        (expanded, parameter) =>
            expanded.replaceAll('\${${parameter.$2}}', arguments[parameter.$1]),
      ),
  ];
}

List<String> expandMacros(List<String> lines, List<String> body) => [
  for (final line in body) ...expandMacroCall(lines, line),
];

int indexContaining(List<String> lines, String text) =>
    lines.indexWhere((line) => line.contains(text));

final nsisString = RegExp(
  r'''"(?:\$\\.|[^"])*"|'(?:\$\\.|[^'])*'|`(?:\$\\.|[^`])*`''',
);
final nsisCommentStart = RegExp(r'(^|\s)(;|#|/\*)');

bool startsComment(String line) =>
    nsisCommentStart.hasMatch(line.replaceAll(nsisString, '""'));

String? runnableMakensis() {
  try {
    final result = Process.runSync('makensis', ['-VERSION']);
    return result.exitCode == 0 ? 'makensis' : null;
  } on ProcessException {
    return null;
  }
}

void main() {
  group('installer is compatible with Tauri installs and updater flags', () {
    late String script;
    late String rendered;
    late List<String> lines;

    setUp(() {
      script = File(scriptPath).readAsStringSync();
      rendered = renderDefines(script);
      lines = trimmedLines(rendered);
    });

    test('is a Unicode installer that never asks for elevation', () {
      expect(lines, contains('Unicode true'));
      expect(lines, contains('RequestExecutionLevel user'));
      expect(lines.where((line) => line.contains('RequestExecutionLevel')), [
        'RequestExecutionLevel user',
      ]);
    });

    test('renders the Tauri template identity', () {
      final defines = scriptDefines(script);

      expect(defines['PRODUCTNAME'], 'Swiftie Quiz');
      expect(defines['MAINBINARYNAME'], 'swiftie-quiz');
      expect(defines['MANUFACTURER'], 'swiftiequiz');
      expect(defines['BUNDLEID'], 'com.swiftiequiz.desktop');
      expect(lines, contains('Name "Swiftie Quiz"'));
      expect(lines, contains(r'OutFile "${OUTFILE}"'));
    });

    test('installs per user into LOCALAPPDATA and reuses the recorded '
        'folder', () {
      expect(lines, contains(r'InstallDir "$LOCALAPPDATA\Swiftie Quiz"'));
      expect(
        lines,
        contains('InstallDirRegKey HKCU "$uninstallKey" "InstallLocation"'),
      );
    });

    test('writes the uninstall key values of the Tauri template', () {
      final install = sectionBody(lines, 'Install');
      final expectedValues = {
        'DisplayName': '"Swiftie Quiz"',
        'DisplayIcon': r'"$\"$INSTDIR\swiftie-quiz.exe$\""',
        'DisplayVersion': r'"${VERSION}"',
        'Publisher': '"swiftiequiz"',
        'UninstallString': r'"$\"$INSTDIR\uninstall.exe$\""',
        'QuietUninstallString': r'"$\"$INSTDIR\uninstall.exe$\" /S"',
        'InstallLocation': r'"$\"$INSTDIR$\""',
        'MainBinaryName': '"swiftie-quiz.exe"',
      };
      for (final entry in expectedValues.entries) {
        expect(
          install,
          contains(
            'WriteRegStr HKCU "$uninstallKey" "${entry.key}" '
            '${entry.value}',
          ),
        );
      }
      for (final name in ['NoModify', 'NoRepair']) {
        expect(
          install,
          contains('WriteRegDWORD HKCU "$uninstallKey" "$name" "1"'),
        );
      }
      expect(
        install,
        contains('WriteRegDWORD HKCU "$uninstallKey" "EstimatedSize" "\$0"'),
      );
      expect(install, contains(r'WriteUninstaller "$INSTDIR\uninstall.exe"'));
    });

    test('records the install folder and language under the manufacturer '
        'key', () {
      expect(
        sectionBody(lines, 'Install'),
        contains('WriteRegStr HKCU "$manufacturerKey" "" \$INSTDIR'),
      );
      expect(lines, contains('!define MUI_LANGDLL_REGISTRY_ROOT "HKCU"'));
      expect(
        lines,
        contains('!define MUI_LANGDLL_REGISTRY_KEY "$manufacturerKey"'),
      );
      expect(
        lines,
        contains('!define MUI_LANGDLL_REGISTRY_VALUENAME "Installer Language"'),
      );
    });

    test('reads /P, /UPDATE and /NS with GetOptions as the template does', () {
      final modes = [
        ...macroBody(lines, 'ReadModeOptions'),
        ...functionBody(lines, '.onInit'),
      ];
      for (final option in {
        '/P': r'$PassiveMode',
        '/UPDATE': r'$UpdateMode',
        '/NS': r'$NoShortcutMode',
      }.entries) {
        final read = modes.indexOf(
          '\${GetOptions} \$CMDLINE "${option.key}" ${option.value}',
        );
        expect(read, isNonNegative, reason: option.key);
        expect(modes[read + 1], r'${IfNot} ${Errors}');
        expect(modes[read + 2], 'StrCpy ${option.value} 1');
      }
      expect(
        functionBody(lines, '.onInit'),
        contains('!insertmacro ReadModeOptions'),
      );
      expect(
        functionBody(lines, 'un.onInit'),
        contains('!insertmacro ReadModeOptions'),
      );
    });

    test('relaunches with /R and the /ARGS that follow it after a passive or '
        'silent install', () {
      final success = functionBody(lines, '.onInstSuccess');

      expect(success.sublist(0, 2), [
        r'${If} $PassiveMode = 1',
        r'${OrIf} ${Silent}',
      ]);
      final relaunch = success.indexOf(r'${GetOptions} $CMDLINE "/R" $R0');
      expect(relaunch, isNonNegative);
      expect(success[relaunch + 1], r'${IfNot} ${Errors}');
      expect(success[relaunch + 2], r'${GetOptions} $CMDLINE "/ARGS" $R0');
      expect(success[relaunch + 3], r'Exec `"$INSTDIR\swiftie-quiz.exe" $R0`');
    });

    test('honours /S through the silent flag NSIS sets', () {
      expect(
        rendered,
        isNot(contains(r'${GetOptions} $CMDLINE "/S"')),
        reason: 'NSIS parses /S itself; the template reads it via \${Silent}',
      );
      expect(sectionBody(lines, 'Install'), contains(r'${OrIf} ${Silent}'));
      expect(
        macroBody(lines, 'CloseRunningApp'),
        contains(r'${IfNot} ${Silent}'),
      );
    });

    test('shows welcome, directory, progress and finish pages, skipping all '
        'but progress in passive mode', () {
      for (final page in [
        'MUI_PAGE_WELCOME',
        'MUI_PAGE_DIRECTORY',
        'MUI_PAGE_FINISH',
      ]) {
        final at = lines.indexOf('!insertmacro $page');
        expect(at, isNonNegative, reason: page);
        expect(
          lines
              .sublist(0, at)
              .lastWhere(
                (line) =>
                    line.startsWith('!define MUI_PAGE_CUSTOMFUNCTION_PRE'),
              ),
          '!define MUI_PAGE_CUSTOMFUNCTION_PRE SkipIfPassive',
          reason: page,
        );
      }
      expect(lines, contains('!insertmacro MUI_PAGE_INSTFILES'));
      expect(lines, contains('!define MUI_FINISHPAGE_RUN'));
      expect(
        lines,
        contains('!define MUI_FINISHPAGE_RUN_FUNCTION RunMainBinary'),
      );
      expect(functionBody(lines, 'RunMainBinary'), [
        r'Exec `"$INSTDIR\swiftie-quiz.exe"`',
      ]);
      expect(functionBody(lines, 'SkipIfPassive'), [
        r'${IfThen} $PassiveMode = 1 ${|} Abort ${|}',
      ]);
      expect(
        lines.indexOf('!insertmacro MUI_PAGE_WELCOME'),
        lessThan(lines.indexOf('!insertmacro MUI_PAGE_DIRECTORY')),
      );
      expect(
        lines.indexOf('!insertmacro MUI_PAGE_DIRECTORY'),
        lessThan(lines.indexOf('!insertmacro MUI_PAGE_INSTFILES')),
      );
      expect(
        lines.indexOf('!insertmacro MUI_PAGE_INSTFILES'),
        lessThan(lines.indexOf('!insertmacro MUI_PAGE_FINISH')),
      );
    });

    test('closes the current user\'s running swiftie-quiz.exe, asking first '
        'unless passive or silent', () {
      final close = macroBody(lines, 'CloseRunningApp');
      final ask = indexContaining(close, 'MessageBox MB_OKCANCEL');
      final kill = indexContaining(
        close,
        r'nsExec::ExecToStack `"$SYSDIR\taskkill.exe" /IM swiftie-quiz.exe /F',
      );

      expect(close.first, r'ReadEnvStr $R3 USERNAME');
      expect(
        close[1],
        r'nsExec::ExecToStack `"$SYSDIR\tasklist.exe" /NH /FO CSV '
        r'/FI "IMAGENAME eq swiftie-quiz.exe" /FI "USERNAME eq $R3"`',
      );
      expect(close[kill], endsWith(r'/FI "USERNAME eq $R3"`'));
      expect(ask, isNonNegative);
      expect(close.sublist(ask - 2, ask), [
        r'${IfNot} ${Silent}',
        r'${AndIf} $PassiveMode <> 1',
      ]);
      expect(close[ask + 1], r'Abort "$(appRunning)"');
      expect(kill, greaterThan(ask));
      expect(
        rendered,
        isNot(contains('nsis_tauri_utils')),
        reason: 'the Tauri plugin DLL is not shipped',
      );
    });

    test('closes the app, then removes Tauri-era files, before copying the '
        'whole release folder', () {
      final install = sectionBody(lines, 'Install');
      final close = install.indexOf('!insertmacro CloseRunningApp');
      final webView = install.indexOf(r'Delete "$INSTDIR\WebView2Loader.dll"');
      final resources = install.indexOf(r'RMDir /r "$INSTDIR\resources"');
      final copy = install.indexOf(r'File /r "${SOURCE_DIR}\*.*"');

      expect(install.first, r'SetOutPath $INSTDIR');
      expect(close, isNonNegative);
      expect(webView, greaterThan(close));
      expect(resources, greaterThan(close));
      expect(copy, greaterThan(webView));
      expect(copy, greaterThan(resources));
    });

    test('creates the Start menu and desktop shortcuts unless /NS or an '
        'update', () {
      final startMenu = functionBody(lines, 'CreateStartMenuShortcut');
      final desktop = functionBody(lines, 'CreateDesktopShortcut');
      const skip = [
        r'${If} $UpdateMode = 1',
        r'${OrIf} $NoShortcutMode = 1',
        'Return',
        r'${EndIf}',
      ];

      expect(startMenu, [
        ...skip,
        r'CreateShortcut "$SMPROGRAMS\Swiftie Quiz.lnk" '
            r'"$INSTDIR\swiftie-quiz.exe"',
      ]);
      expect(desktop, [
        ...skip,
        r'CreateShortcut "$DESKTOP\Swiftie Quiz.lnk" '
            r'"$INSTDIR\swiftie-quiz.exe"',
      ]);
      final install = sectionBody(lines, 'Install');
      expect(install, contains('Call CreateStartMenuShortcut'));
      final desktopCall = install.indexOf('Call CreateDesktopShortcut');
      expect(install.sublist(desktopCall - 2, desktopCall), [
        r'${If} $PassiveMode = 1',
        r'${OrIf} ${Silent}',
      ]);
      expect(
        lines,
        contains(
          '!define MUI_FINISHPAGE_SHOWREADME_FUNCTION CreateDesktopShortcut',
        ),
      );
    });

    test('uninstaller removes files, shortcuts and keys and keeps the save '
        'unless asked', () {
      final uninstall = expandMacros(lines, sectionBody(lines, 'Uninstall'));

      expect(
        uninstall.sublist(0, macroBody(lines, 'CloseRunningApp').length),
        macroBody(lines, 'CloseRunningApp'),
      );
      for (final removal in [
        r'Delete "$INSTDIR\swiftie-quiz.exe"',
        r'Delete "$INSTDIR\*.dll"',
        r'RMDir /r "$INSTDIR\data"',
        r'Delete "$INSTDIR\uninstall.exe"',
        r'RMDir "$INSTDIR"',
        r'Delete "$SMPROGRAMS\Swiftie Quiz.lnk"',
        r'Delete "$DESKTOP\Swiftie Quiz.lnk"',
        'DeleteRegKey HKCU "$uninstallKey"',
      ]) {
        expect(uninstall, contains(removal));
      }
      expect(
        uninstall.where((line) => line.startsWith('RMDir /r "\$INSTDIR"')),
        isEmpty,
      );

      final manufacturerRemoval = uninstall.indexOf(
        'DeleteRegKey HKCU "$manufacturerKey"',
      );
      expect(manufacturerRemoval, isNonNegative);
      expect(
        uninstall[manufacturerRemoval + 1],
        r'DeleteRegKey /ifempty HKCU "Software\swiftiequiz"',
      );
      expect(
        uninstall
            .sublist(0, manufacturerRemoval)
            .lastWhere((line) => line.startsWith(r'${If}')),
        r'${If} $UpdateMode <> 1',
      );

      final appData = uninstall.indexOf(
        r'RMDir /r "$APPDATA\com.swiftiequiz.desktop"',
      );
      expect(appData, isNonNegative);
      final guard = uninstall
          .sublist(0, appData)
          .lastIndexOf(r'${If} $DeleteAppDataCheckboxState = 1');
      expect(guard, isNonNegative);
      expect(uninstall[guard + 1], r'${AndIf} $UpdateMode <> 1');
      expect(
        uninstall.sublist(guard, appData).where((l) => l == r'${EndIf}'),
        isEmpty,
      );
      expect(
        rendered.split('\n').where((line) => line.contains(r'$APPDATA\')),
        hasLength(1),
      );
      expect(
        lines,
        contains('!define MUI_PAGE_CUSTOMFUNCTION_SHOW un.ConfirmShow'),
      );
      expect(
        functionBody(lines, 'un.ConfirmLeave'),
        contains(
          r'SendMessage $DeleteAppDataCheckbox ${BM_GETCHECK} 0 0 '
          r'$DeleteAppDataCheckboxState',
        ),
      );
    });

    test('contains no NSIS comments', () {
      final commentLines = [
        for (final (index, line) in script.split('\n').indexed)
          if (startsComment(line)) '${index + 1}: $line',
      ];

      expect(startsComment('; note'), isTrue);
      expect(startsComment('Delete "a" ; note'), isTrue);
      expect(startsComment('  # note'), isTrue);
      expect(startsComment('Name "a" /* note */'), isTrue);
      expect(startsComment('FindWindow \$1 "#32770" "" \$HWNDPARENT'), isFalse);
      expect(
        startsComment(r'WriteRegStr HKCU "k" "v" "$\"a;b$\" /S"'),
        isFalse,
      );
      expect(commentLines, isEmpty);
    });

    test('compiles with makensis against a release folder', () {
      final makensis = runnableMakensis();
      if (makensis == null) {
        markTestSkipped(
          'makensis is not installed (brew install makensis to run this)',
        );
        return;
      }
      final temp = Directory.systemTemp.createTempSync('swiftie_nsis_');
      addTearDown(() => temp.deleteSync(recursive: true));
      final release = Directory('${temp.path}/Release');
      Directory('${release.path}/data/flutter_assets')
          .createSync(recursive: true);
      File('${release.path}/swiftie-quiz.exe').writeAsStringSync('MZ');
      File('${release.path}/flutter_windows.dll').writeAsStringSync('dll');
      File('${release.path}/data/flutter_assets/AssetManifest.bin')
          .writeAsStringSync('assets');
      final setup = File('${temp.path}/Swiftie Quiz_0.3.0_x64-setup.exe');

      final result = Process.runSync(makensis, [
        '-WX',
        '-V2',
        '-DSOURCE_DIR=${release.path}',
        '-DVERSION=0.3.0',
        '-DOUTFILE=${setup.path}',
        scriptPath,
      ]);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(setup.existsSync(), isTrue);
      expect(setup.lengthSync(), greaterThan(0));
    });
  });
}
