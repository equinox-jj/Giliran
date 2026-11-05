import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_doodles.dart';
import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/services/push_service.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/clock.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/entities/notification_entry.dart';
import '../../shared/controllers/push_permission_controller.dart';
import '../../shared/widgets/day_header.dart';
import '../controllers/notifications_controller.dart';

/// The Aktivitas tab: pushes received on this device, grouped by
/// day, under the chips Semua · Belum dibaca · Perlu tindakan, with "Tandai
/// semua dibaca" in the app bar and a banner while the OS blocks
/// notifications. Tapping an item marks it read and opens its target.
class const NotificationsPage({super.key, required final ValueChanged<NotificationTarget> onOpen})
    extends ConsumerStatefulWidget {
  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState() extends ConsumerState<NotificationsPage> {
  Future<void> _open(NotificationEntry entry) async {
    final target = await ref.read(notificationsControllerProvider.notifier).open(entry);
    if (mounted) widget.onOpen(target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: context.l10n.tabActivity,
        showBack: false,
        actions: const [_MarkAllRead()],
      ),
      body: _Body(onOpen: _open),
    );
  }
}

class const _MarkAllRead() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnread = ref.watch(notificationsControllerProvider.select((s) => s.hasUnread));
    return AppTextButton(
      label: context.l10n.notificationsMarkAllRead,
      onPressed: hasUnread ? () => ref.read(notificationsControllerProvider.notifier).markAllRead() : null,
    );
  }
}

class const _Body({required final ValueChanged<NotificationEntry> onOpen}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);
    final now = ref.watch(clockProvider)();
    final margin = context.screenMargin;
    final entries = state.entries;
    final bottom = context.isCompact ? AppBottomNavBar.contentInset(context) : AppSpace.s8;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: margin),
          sliver: SliverToBoxAdapter(
            child: MaxWidth(child: _Header(filter: state.filter)),
          ),
        ),
        if (!state.loaded)
          const SliverToBoxAdapter(child: SizedBox.shrink())
        else if (entries.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              illustration: const Doodle(AppDoodles.phone, size: 120),
              title: state.filter == NotificationFilter.all
                  ? context.l10n.notificationsEmpty
                  : context.l10n.notificationsEmptyFiltered,
            ),
          )
        else
          SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final entry = entries[i];
              final day = AppDate.jakartaToday(entry.createdAt);
              final first = i == 0 || AppDate.jakartaToday(entries[i - 1].createdAt) != day;
              return MaxWidth(
                child: _Item(entry: entry, header: first ? day : null, now: now, margin: margin, onOpen: onOpen),
              );
            },
          ),
        SliverPadding(padding: EdgeInsets.only(bottom: bottom)),
      ],
    );
  }
}

class const _Header({required final NotificationFilter filter}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.watch(notificationsControllerProvider.notifier);
    final labels = {
      NotificationFilter.all: l10n.notificationsFilterAll,
      NotificationFilter.unread: l10n.notificationsFilterUnread,
      NotificationFilter.needsAction: l10n.notificationsFilterAction,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.s2),
        Semantics(header: true, child: HeadlineText(l10n.notificationsHeadline)),
        const _PushOffBanner(),
        const SizedBox(height: AppSpace.s4),
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          children: [
            for (final MapEntry(key: f, value: label) in labels.entries)
              AppChip(label: label, selected: f == filter, onSelected: () => controller.setFilter(f)),
          ],
        ),
        const SizedBox(height: AppSpace.s2),
      ],
    );
  }
}

/// "Notifikasi mati. …" with "Buka pengaturan", while the OS blocks
/// notifications.
class const _PushOffBanner() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(pushPermissionControllerProvider.select((s) => s.value));
    if (permission == null || permission == PushPermission.granted) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s4),
      child: AppBanner(
        message: l10n.notificationsPushOff,
        icon: AppIcons.bellSimple,
        actionLabel: l10n.notificationsOpenSettings,
        onAction: () => ref.read(pushPermissionControllerProvider.notifier).enable(),
      ),
    );
  }
}

class const _Item({
  required final NotificationEntry entry,
  required final DateTime? header,
  required final DateTime now,
  required final double margin,
  required final ValueChanged<NotificationEntry> onOpen,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final day = header;
    final gid = entry.groupId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (day != null)
          DayHeader(day: day, now: now, padding: EdgeInsets.fromLTRB(margin, AppSpace.s4, margin, AppSpace.s1)),
        NotificationItem(
          id: entry.id,
          icon: _icon(entry.kind),
          title: entry.title ?? l10n.notificationFallbackTitle,
          body: entry.body,
          time: AppDate.time(AppDate.jakarta(entry.createdAt)),
          groupName: entry.groupName,
          toneColor: gid == null ? null : c.toneFor(gid).accent,
          read: entry.read,
          onTap: () => onOpen(entry),
          onMarkRead: () => ref.read(notificationsControllerProvider.notifier).markRead(entry.id),
        ),
      ],
    );
  }

  static String _icon(PushKind kind) => switch (kind) {
    PushKind.paymentReminder => AppIcons.bellRinging,
    PushKind.proofUploaded => AppIcons.receipt,
    PushKind.paymentApproved => AppIcons.checkCircle,
    PushKind.paymentRejected => AppIcons.xCircle,
    PushKind.paymentMarkedPaid => AppIcons.money,
    PushKind.drawCompleted => AppIcons.shuffle,
    PushKind.payoutRecorded => AppIcons.handCoins,
    PushKind.obligationsMissed => AppIcons.warningCircle,
    PushKind.unknown => AppIcons.bellSimple,
  };
}
