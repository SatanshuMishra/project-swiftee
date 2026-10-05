import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/save/save_error.dart';
import 'package:swiftie_quiz/data/save/save_location.dart';

void main() {
  group('save path matches the Tauri app data directory', () {
    test('macOS resolves under HOME/Library/Application Support', () {
      expect(
        saveFilePath(isMacOS: true, environment: const {'HOME': '/Users/a'}),
        '/Users/a/Library/Application Support/com.swiftiequiz.desktop/save.json',
      );
    });

    test('Windows resolves under APPDATA', () {
      expect(
        saveFilePath(
          isMacOS: false,
          environment: const {'APPDATA': r'C:\Users\a\AppData\Roaming'},
        ),
        r'C:\Users\a\AppData\Roaming\com.swiftiequiz.desktop\save.json',
      );
    });

    test('macOS without HOME is a file error', () {
      expect(
        () => saveFilePath(
          isMacOS: true,
          environment: const {'APPDATA': r'C:\Users\a\AppData\Roaming'},
        ),
        throwsA(
          isA<SaveFileError>().having(
            (error) => error.message,
            'message',
            'File error: HOME is not set',
          ),
        ),
      );
    });

    test('Windows without APPDATA is a file error', () {
      expect(
        () => saveFilePath(
          isMacOS: false,
          environment: const {'HOME': '/Users/a'},
        ),
        throwsA(
          isA<SaveFileError>().having(
            (error) => error.message,
            'message',
            'File error: APPDATA is not set',
          ),
        ),
      );
    });

    test('an empty variable counts as missing', () {
      expect(
        () => saveFilePath(isMacOS: true, environment: const {'HOME': ''}),
        throwsA(isA<SaveFileError>()),
      );
    });
  });
}
