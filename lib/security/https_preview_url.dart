/// Evidence previews may fetch HTTPS URLs only.
///
/// Cleartext `http://` is never a valid Firebase Storage download URL and
/// must not be passed to [Image.network].
bool isHttpsPreviewUrl(String path) {
  return path.trim().toLowerCase().startsWith('https://');
}
