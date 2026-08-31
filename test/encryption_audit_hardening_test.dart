import 'dart:io';

import 'package:evidence_vault/diagnostics/file_final_trace.dart';
import 'package:evidence_vault/diagnostics/file_p0_trace.dart';
import 'package:evidence_vault/presentation/trust_security_copy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('honest product language', () {
    test('splash and login no longer claim encryption or end-to-end', () {
      expect(TrustSecurityCopy.splashProtectionTitle, 'Protected');
      expect(TrustSecurityCopy.splashProtectionSubtitle, 'On this device');
      expect(
        TrustSecurityCopy.loginPrivacyCaption,
        'Your evidence stays on this device. You control what you share.',
      );

      const claimed = [
        TrustSecurityCopy.splashProtectionTitle,
        TrustSecurityCopy.splashProtectionSubtitle,
        TrustSecurityCopy.loginPrivacyCaption,
      ];
      for (final line in claimed) {
        expect(line.toLowerCase(), isNot(contains('encrypt')));
        expect(line.toLowerCase(), isNot(contains('end-to-end')));
        expect(line.toLowerCase(), isNot(contains('e2e')));
      }
    });
  });

  group('attachment diagnostics', () {
    test('FILEP0 and FILEFINAL omit the local evidence path', () {
      final lines = <String>[];
      final previous = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          lines.add(message);
        }
      };
      addTearDown(() => debugPrint = previous);

      const secret = '/data/data/com.example.evidence_vault/app_flutter/'
          'evidence_cache/inc-1/secret.jpg';
      FileP0Trace.step(
        'TEST_STEP',
        fileName: 'secret.jpg',
        fileSize: 12,
        path: secret,
      );
      FileFinalTrace.stage(
        'TEST_STAGE',
        fileName: 'secret.jpg',
        fileSize: 12,
        path: secret,
      );
      FileFinalTrace.failure(
        'TEST_FAIL',
        fileName: 'secret.jpg',
        path: secret,
      );

      final joined = lines.join('\n');
      expect(joined, isNot(contains(secret)));
      expect(joined, isNot(contains('path=')));
      expect(joined, contains('fileName=secret.jpg'));
    });
  });

  group('Android backup exclusions', () {
    test('backup rules exclude plaintext evidence directories', () {
      final backup = File(
        'android/app/src/main/res/xml/backup_rules.xml',
      ).readAsStringSync();
      final extraction = File(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      ).readAsStringSync();
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      for (final xml in [backup, extraction]) {
        expect(xml, contains('evidence_cache'));
        expect(xml, contains('trust_package_exports'));
      }
      expect(manifest, contains('android:allowBackup="true"'));
      expect(manifest, contains('@xml/backup_rules'));
      expect(manifest, contains('@xml/data_extraction_rules'));
    });
  });
}
