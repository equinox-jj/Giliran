import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readArb(String locale) =>
    jsonDecode(File('lib/core/l10n/app_$locale.arb').readAsStringSync()) as Map<String, dynamic>;

Set<String> _messageKeys(Map<String, dynamic> arb) => arb.keys.where((k) => !k.startsWith('@')).toSet();

/// Placeholder names used in [message] (`{name}` or `{name, plural, …}`),
/// limited to [declared] so ICU branch text such as `other{orang}` is not
/// mistaken for a placeholder.
Set<String> _usedPlaceholders(String message, Set<String> declared) =>
    RegExp(r'\{(\w+)[,}]').allMatches(message).map((m) => m.group(1)!).where(declared.contains).toSet();

Set<String> _declaredPlaceholders(Map<String, dynamic> arb, String key) {
  final meta = arb['@$key'];
  if (meta is! Map<String, dynamic>) return {};
  final placeholders = meta['placeholders'];
  if (placeholders is! Map<String, dynamic>) return {};
  return placeholders.keys.toSet();
}

void main() {
  test('the Indonesian and English ARB files have the same keys', () {
    // Arrange
    final id = _readArb('id');
    final en = _readArb('en');

    // Act
    final missingInEn = _messageKeys(id).difference(_messageKeys(en));
    final extraInEn = _messageKeys(en).difference(_messageKeys(id));

    // Assert
    expect(missingInEn, isEmpty, reason: 'keys missing from app_en.arb');
    expect(extraInEn, isEmpty, reason: 'keys only in app_en.arb');
  });

  test('every message uses its declared placeholders in both languages', () {
    // Arrange
    final id = _readArb('id');
    final en = _readArb('en');
    final mismatches = <String>[];

    // Act
    for (final key in _messageKeys(id).intersection(_messageKeys(en))) {
      final declared = _declaredPlaceholders(id, key);
      final inId = _usedPlaceholders(id[key] as String, declared);
      final inEn = _usedPlaceholders(en[key] as String, declared);
      if (inId.length != declared.length || inEn.length != declared.length) {
        mismatches.add('$key: declared $declared, id $inId, en $inEn');
      }
    }

    // Assert
    expect(mismatches, isEmpty);
  });

  test('no message in app_id.arb uses an undeclared placeholder', () {
    // Arrange
    final id = _readArb('id');
    final undeclared = <String>[];

    // Act
    for (final key in _messageKeys(id)) {
      final declared = _declaredPlaceholders(id, key);
      final message = id[key] as String;
      // Only plain `{name}` tokens: ICU branch bodies never look like that
      // unless they nest a placeholder, which must then be declared too.
      final tokens = RegExp(r'\{(\w+)\}')
          .allMatches(message)
          .map((m) => m.group(1)!)
          .where((name) => !RegExp(r'^\d').hasMatch(name));
      final isIcu = RegExp(r'\{\w+,\s*(plural|select)').hasMatch(message);
      for (final name in tokens) {
        if (!declared.contains(name) && !isIcu) undeclared.add('$key: $name');
      }
    }

    // Assert
    expect(undeclared, isEmpty);
  });
}
