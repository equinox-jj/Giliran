/// Placeholder written in place of a sensitive value.
const redactedValue = '«redacted»';

/// Map keys whose values never reach a log, compared after [normalizeKey].
///
/// `code` is deliberately absent: it is the API error code, which logs need.
/// Verification codes travel as `otp` or `verification_code`.
const sensitiveKeys = {
  'password',
  'pin',
  'currentpin',
  'newpin',
  'otp',
  'verificationcode',
  'token',
  'accesstoken',
  'refreshtoken',
  'idtoken',
  'authorization',
  'cookie',
  'setcookie',
  'secret',
  'apikey',
  'email',
  'phone',
  'whatsapp',
  'accountnumber',
  'accountholder',
  'qris',
  'qrispayload',
};

/// Lower-cases [key] and drops `_` and `-`, so `refresh_token`,
/// `refreshToken` and `Refresh-Token` compare equal.
String normalizeKey(String key) => key.toLowerCase().replaceAll(RegExp('[_-]'), '');

/// Returns a copy of [value] that is safe to log.
///
/// Maps have the values of [sensitiveKeys] replaced by [redactedValue],
/// lists and maps are walked recursively, and strings go through [scrub].
/// Other values are returned unchanged.
Object? redact(Object? value) => switch (value) {
  Map() => {
    for (final entry in value.entries)
      '${entry.key}': sensitiveKeys.contains(normalizeKey('${entry.key}')) ? redactedValue : redact(entry.value),
  },
  Iterable() => [for (final item in value) redact(item)],
  String() => scrub(value),
  _ => value,
};

final _bearer = RegExp(r'\bBearer\s+[^\s,;"]+', caseSensitive: false);
final _jwt = RegExp(r'\beyJ[\w-]+\.[\w-]+\.[\w-]+');
final _email = RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+');
final _phone = RegExp(r'(?<![\w.])((\+?62)[ -]?|0)8[\d -]{7,14}\d(?!\w)');

/// Masks secrets that appear in free text: bearer tokens, JWTs, emails and
/// Indonesian phone numbers.
///
/// Plain numbers such as amounts are left alone; PINs and codes are caught
/// by key in [redact] instead.
String scrub(String text) => text
    .replaceAll(_bearer, 'Bearer $redactedValue')
    .replaceAll(_jwt, redactedValue)
    .replaceAll(_email, '«email»')
    .replaceAll(_phone, '«phone»');
