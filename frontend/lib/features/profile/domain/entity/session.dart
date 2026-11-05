import 'package:freezed_annotation/freezed_annotation.dart';

part 'session.freezed.dart';

/// A device signed in to the account, shown on Security.
@freezed
abstract class Session with _$Session {
  const factory({
    String? id,
    String? deviceName,

    /// `android` or `ios`.
    String? devicePlatform,
    DateTime? lastActiveAt,
    DateTime? createdAt,

    /// The device this app runs on.
    bool? isCurrent,
  }) = _Session;
}
