import 'dart:io';

import 'package:evidence_vault/diagnostics/release_log_sanitizer.dart';
import 'package:evidence_vault/presentation/trust_security_copy.dart';
import 'package:evidence_vault/security/https_preview_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase rules contract', () {
    late String firestore;
    late String storage;

    setUpAll(() {
      firestore = File('firestore.rules').readAsStringSync();
      storage = File('storage.rules').readAsStringSync();
    });

    test('unauthenticated access is not granted', () {
      expect(firestore, isNot(contains('if true')));
      expect(storage, isNot(contains('if true')));
      expect(firestore, contains('request.auth != null'));
      expect(storage, contains('request.auth != null'));
    });

    test('owner isolation is path-uid based', () {
      expect(firestore, contains('request.auth.uid == userId'));
      expect(storage, contains('request.auth.uid == userId'));
      expect(firestore, contains('match /users/{userId}'));
    });

    test('User A cannot use User B path — isOwner required for incidents', () {
      expect(
        firestore,
        contains('allow read: if isOwner(userId);'),
      );
      expect(
        firestore,
        contains('request.resource.data.ownerId == userId'),
      );
      expect(
        firestore,
        contains('request.resource.data.userId == userId'),
      );
    });

    test('participants subcollection is owned', () {
      expect(firestore, contains('match /participants/{docId}'));
      expect(
        firestore,
        contains(RegExp(
          r'match /participants/\{docId\} \{\s*'
          r'allow read, create, update, delete: if isOwner\(userId\);',
        )),
      );
    });

    test('Storage read/create/delete require owner; updates denied', () {
      expect(storage, contains('allow read: if isOwner(userId)'));
      expect(storage, contains('allow create: if isOwner(userId)'));
      expect(storage, contains('allow delete: if isOwner(userId)'));
      expect(storage, contains('allow update: if false'));
    });
  });

  group('HTTPS preview URLs', () {
    test('accepts https Storage URLs and rejects cleartext', () {
      expect(
        isHttpsPreviewUrl(
          'https://firebasestorage.googleapis.com/v0/b/bucket/o/x',
        ),
        isTrue,
      );
      expect(isHttpsPreviewUrl('http://evil.example/photo.jpg'), isFalse);
      expect(isHttpsPreviewUrl('/data/user/0/app/evidence_cache/a.jpg'), isFalse);
    });
  });

  group('Release log redaction', () {
    test('strips tokens, download URLs, uid, GPS, and credentials', () {
      const leaked =
          'user=abc123 uid=abc123 title=Street title=Fight '
          'downloadUrl=https://firebasestorage.googleapis.com/v0/b/x/o/y?token=sekret '
          'Bearer ya29.secret path=/data/secret.jpg sha256=deadbeef '
          'latitude=51.5 longitude=-0.1 password=hunter2 '
          'idToken=eyJhbGci accessToken=1/abc '
          'agent@example.com';
      final sanitized = ReleaseLogSanitizer.sanitize(leaked)!;
      expect(sanitized, isNot(contains('abc123')));
      expect(sanitized, isNot(contains('Street')));
      expect(sanitized, isNot(contains('firebasestorage')));
      expect(sanitized, isNot(contains('sekret')));
      expect(sanitized, isNot(contains('ya29')));
      expect(sanitized, isNot(contains('/data/secret.jpg')));
      expect(sanitized, isNot(contains('deadbeef')));
      expect(sanitized, isNot(contains('51.5')));
      expect(sanitized, isNot(contains('hunter2')));
      expect(sanitized, isNot(contains('eyJhbGci')));
      expect(sanitized, isNot(contains('agent@example.com')));
      expect(sanitized, contains('[redacted]'));
      expect(sanitized, contains('[redacted-email]'));
      expect(
        ReleaseLogSanitizer.sanitize(
          'see https://firebasestorage.googleapis.com/v0/b/x/o/y',
        ),
        contains('[redacted-url]'),
      );
    });
  });

  group('Android network and backup', () {
    test('cleartext is disabled in manifest and network security config', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final nsc = File(
        'android/app/src/main/res/xml/network_security_config.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:usesCleartextTraffic="false"'));
      expect(
        manifest,
        contains('android:networkSecurityConfig="@xml/network_security_config"'),
      );
      expect(nsc, contains('cleartextTrafficPermitted="false"'));
      expect(nsc, contains('src="system"'));
      expect(nsc, isNot(contains('src="user"')));
    });

    test('release build is not debuggable and does not invent a keystore', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('isDebuggable = false'));
      expect(gradle, contains('signingConfigs.getByName("debug")'));
      expect(gradle, isNot(contains('storePassword')));
      expect(gradle, isNot(contains('keyPassword')));
    });
  });

  group('Sign-out vs account deletion', () {
    test('sign-out does not wipe the evidence cache', () {
      final source = File(
        'lib/services/auth/authentication_service.dart',
      ).readAsStringSync();
      expect(source, contains('SafStagingBridge.discardAll'));
      expect(source, isNot(contains('LocalEvidenceCache.clearAll')));
      expect(source, contains('Do NOT delete evidence_cache'));
    });

    test('account deletion still wipes investigation data before Auth delete', () {
      final source = File(
        'lib/services/account_deletion_service.dart',
      ).readAsStringSync();
      expect(source, contains('deleteAllInvestigationData'));
      expect(source, contains('deleteFirebaseAccount'));
    });

    test('cloud wipe deletes Storage prefixes then owned Firestore trees', () {
      final deletion = File(
        'lib/services/investigation_data_deletion_service.dart',
      ).readAsStringSync();
      final repo = File(
        'lib/repositories/firebase/firebase_incident_repository.dart',
      ).readAsStringSync();
      expect(deletion, contains('deleteIncidentOwnedPrefix'));
      expect(deletion, contains('listIncidentIds'));
      expect(repo, contains('deleteOwnedIncidentTree'));
      expect(
        repo,
        contains('_deleteCollectionDocs(FirestorePaths.incidentCollections'),
      );
    });
  });

  group('Privacy copy', () {
    test('does not imply local-only storage', () {
      expect(
        TrustSecurityCopy.loginPrivacyCaption.toLowerCase(),
        contains('synced'),
      );
      expect(
        TrustSecurityCopy.loginPrivacyCaption.toLowerCase(),
        isNot(contains('encrypt')),
      );
    });
  });
}
