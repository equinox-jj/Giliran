import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'parse_invite_code_usecase.g.dart';

/// Reads an invite code from what the user pasted on Home's "Gabung lewat
/// link" sheet: a link such as `https://giliran.monai.my.id/j/K7P2QX9M`, or
/// the code itself (spaces and case don't matter). Null when it is neither.
///
/// Pure and synchronous, so it does not go through `UseCase`.
class const ParseInviteCodeUseCase() {
  static final _code = RegExp(r'^[A-Z0-9]{8}$');

  String? call(String input) {
    final text = input.trim();
    final uri = Uri.tryParse(text);
    final segments = uri?.pathSegments ?? const <String>[];
    final index = segments.indexOf('j');
    final raw = uri != null && uri.hasScheme && index >= 0 && index + 1 < segments.length
        ? segments[index + 1]
        : text.replaceAll(RegExp(r'\s'), '');
    final code = raw.toUpperCase();
    return _code.hasMatch(code) ? code : null;
  }
}

@Riverpod(keepAlive: true)
ParseInviteCodeUseCase parseInviteCodeUseCase(Ref ref) => const ParseInviteCodeUseCase();
