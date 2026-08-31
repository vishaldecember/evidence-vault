/// Honest security language. Do not claim encryption or E2E here.
///
/// Local originals are stored as plaintext files. Firebase uses TLS in
/// transit and Google-managed at-rest keys — not Evidence Vault E2E.
abstract final class TrustSecurityCopy {
  static const splashProtectionTitle = 'Protected';
  static const splashProtectionSubtitle = 'On this device';

  static const loginPrivacyCaption =
      'Your evidence stays on this device. You control what you share.';
}
