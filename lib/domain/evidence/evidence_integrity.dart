import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// SHA-256 fingerprint of a preserved original payload.
///
/// Does not verify real-world events, authorship, or independent review.
/// A recorded hash only means: this fingerprint belongs to those bytes.
abstract final class EvidenceIntegrity {
  /// Hex SHA-256 of [bytes]. Does not transform the payload.
  static String sha256OfBytes(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Hex SHA-256 of the UTF-8 encoding of [text].
  ///
  /// Canonical text representation: the exact stored note body, UTF-8.
  static String sha256OfUtf8(String text) {
    return sha256OfBytes(utf8.encode(text));
  }

  /// Hex SHA-256 of the file at [path] as stored. Never a thumbnail.
  ///
  /// File read + digest run off the UI isolate. Does not change the
  /// fingerprint algorithm or which bytes are hashed.
  @visibleForTesting
  static Future<String> Function(String path)? debugSha256OfFile;

  static Future<String> sha256OfFile(String path) async {
    final override = debugSha256OfFile;
    if (override != null) {
      return override(path);
    }
    if (kIsWeb) {
      final bytes = await File(path).readAsBytes();
      return sha256OfBytes(bytes);
    }
    return Isolate.run(() => _sha256OfFileSync(path));
  }

  static String _sha256OfFileSync(String path) {
    final bytes = File(path).readAsBytesSync();
    return sha256.convert(bytes).toString();
  }

  static EvidenceIntegrityCheck compare({
    required String? recorded,
    required String recomputed,
  }) {
    final expected = recorded?.trim() ?? '';
    if (expected.isEmpty) {
      return EvidenceIntegrityCheck.hashNotRecorded;
    }
    return expected == recomputed
        ? EvidenceIntegrityCheck.match
        : EvidenceIntegrityCheck.mismatch;
  }

  /// Recomputes from the preserved original — never [thumbnailPath].
  static Future<EvidenceIntegrityCheck> verifyOriginal({
    required String? recordedHash,
    String? originalFilePath,
    String? thumbnailPath,
    String? noteText,
  }) async {
    final expected = recordedHash?.trim() ?? '';
    if (expected.isEmpty) {
      return EvidenceIntegrityCheck.hashNotRecorded;
    }

    final original = originalFilePath?.trim() ?? '';
    final thumb = thumbnailPath?.trim() ?? '';
    if (original.isNotEmpty && original != thumb && !kIsWeb) {
      try {
        final recomputed = await sha256OfFile(original);
        return compare(recorded: expected, recomputed: recomputed);
      } catch (_) {
        // Fall through to text payload when the original file is unavailable.
      }
    }

    final text = noteText;
    if (text != null && text.isNotEmpty) {
      return compare(recorded: expected, recomputed: sha256OfUtf8(text));
    }
    return EvidenceIntegrityCheck.payloadUnavailable;
  }

  /// Sync counterpart of [verifyOriginal] for Trust Pack assembly.
  ///
  /// Same honesty rules: original bytes only, never a thumbnail.
  static EvidenceIntegrityCheck classifyAvailable({
    required String? recordedHash,
    String? originalFilePath,
    String? thumbnailPath,
    String? noteText,
  }) {
    final expected = recordedHash?.trim() ?? '';
    if (expected.isEmpty) {
      return EvidenceIntegrityCheck.hashNotRecorded;
    }

    final original = originalFilePath?.trim() ?? '';
    final thumb = thumbnailPath?.trim() ?? '';
    final originalExpected = original.isNotEmpty && original != thumb;
    if (originalExpected && !kIsWeb) {
      try {
        final file = File(original);
        if (file.existsSync()) {
          return compare(
            recorded: expected,
            recomputed: sha256OfBytes(file.readAsBytesSync()),
          );
        }
      } catch (_) {
        // Original path is known but bytes are not readable.
      }
      return EvidenceIntegrityCheck.payloadUnavailable;
    }

    final text = noteText;
    if (text != null && text.isNotEmpty) {
      return compare(recorded: expected, recomputed: sha256OfUtf8(text));
    }
    return EvidenceIntegrityCheck.payloadUnavailable;
  }
}

enum EvidenceIntegrityCheck {
  match,
  mismatch,
  hashNotRecorded,
  payloadUnavailable,
}
