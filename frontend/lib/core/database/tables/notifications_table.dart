import 'package:drift/drift.dart';

/// Push notifications received on this device, for the Aktivitas tab
///. Not mirrored from the API: rows come from FCM payloads, and the
/// read flag is local only.
@DataClassName('NotificationRow')
@TableIndex.sql('CREATE INDEX notifications_created_idx ON notifications (created_at DESC)')
class Notifications() extends Table {
  /// The FCM message id (or a generated one when FCM sends none), so a
  /// message stored in the background and again on tap is kept once.
  TextColumn get id => text()();

  /// The push kind from `data.type`, such as `payment.reminder`.
  TextColumn get type => text()();

  /// No foreign key: the push can arrive before the group is cached.
  TextColumn get groupId => text().nullable()();
  TextColumn get periodId => text().nullable()();
  TextColumn get paymentId => text().nullable()();
  TextColumn get payoutId => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get body => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get read => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  bool get isStrict => true;
}
