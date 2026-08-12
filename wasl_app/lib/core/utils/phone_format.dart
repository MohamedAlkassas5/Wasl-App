/// Phone numbers are stored server-side in international form without a
/// leading `+` (e.g. "201220346717" for the Egyptian number 01220346717),
/// which is correct for storage but reads oddly shown to a driver or customer
/// mid-order — a screen showing "201220346717" instead of "01220346717" looks
/// like a data bug even though nothing is actually wrong.
///
/// This converts the stored form back to the familiar local form for display
/// only. It never touches what gets sent to the server.
String formatPhoneForDisplay(String? raw) {
  if (raw == null || raw.isEmpty) return 'غير متوفر';

  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

  // Egypt: country code 20 + a 10-digit local number starting with 1
  // (e.g. 20 1220346717 -> 01220346717). Only rewrite when that shape
  // actually matches, so any other country's number passes through as-is
  // rather than being mangled.
  if (digits.length == 12 && digits.startsWith('201')) {
    return '0${digits.substring(2)}';
  }

  return raw;
}
