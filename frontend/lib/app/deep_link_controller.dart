import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/storage/preferences.dart';

part 'deep_link_controller.g.dart';

/// Keeps an invite (`/j/:code`) or claim (`/c/:token`) link that was opened
/// before the user could see it (signed out, mid-onboarding, session still
/// loading), so the router can resume it once the session is unlocked. An
/// invite link is stored too, so it survives an app restart during sign-in. A
/// claim link holds a bearer token that takes over a guest slot, so it stays
/// in memory and is never written to shared preferences.
///
/// A plain class rather than Riverpod state: the router reads and changes it
/// inside `redirect`, which can run while widgets build.
class DeepLinkController(final Preferences _preferences) {
  String? _pending;

  /// The link waiting to be resumed, if any.
  String? get pending => _pending;

  /// Loads a link stored by an earlier run, unless one arrived meanwhile.
  Future<void> restore() async {
    final saved = await _preferences.readPendingDeepLink();
    _pending ??= saved;
  }

  void remember(String location) {
    _pending = location;
    // Drop any stored link too, so a stale one can't come back on restart.
    unawaited(_preferences.savePendingDeepLink(_isPersistable(location) ? location : null));
  }

  /// Returns the pending link and clears it, so it resumes only once.
  String? consumePending() {
    final link = _pending;
    if (link == null) return null;
    _pending = null;
    unawaited(_preferences.savePendingDeepLink(null));
    return link;
  }

  static bool _isPersistable(String location) => location.startsWith('/j/');

  /// Whether [path] is a link worth resuming after sign-in.
  static bool isResumable(String path) => path.startsWith('/j/') || path.startsWith('/c/');
}

@Riverpod(keepAlive: true)
DeepLinkController deepLinkController(Ref ref) {
  final controller = DeepLinkController(ref.watch(preferencesProvider));
  unawaited(controller.restore());
  return controller;
}
