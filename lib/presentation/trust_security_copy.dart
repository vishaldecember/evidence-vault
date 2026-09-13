/// Honest security language. Do not claim encryption or E2E here.
///
/// Local originals are stored as plaintext files. Firebase uses TLS in
/// transit and Google-managed at-rest keys — not Evidence Vault E2E.
/// At-rest encryption is deferred (Phase 2B): encrypting now would break
/// SAF attach recovery and local playback.
abstract final class TrustSecurityCopy {
  static const splashProtectionTitle = 'Protected';
  static const splashProtectionSubtitle = 'On this device';

  static const loginPrivacyCaption =
      'Evidence is stored on this device and synced to your account. '
      'You control what you share.';
}
