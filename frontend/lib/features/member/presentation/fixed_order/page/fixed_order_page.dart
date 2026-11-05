import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/enums/group_status.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../../group/presentation/group_detail/controllers/group_detail_controller.dart';
import '../../../domain/entities/member.dart';
import '../controllers/fixed_order_controller.dart';

/// Fixed order: "Atur urutan giliran", drag or move rows (1 wins
/// first), "Acak urutan" with undo, and a docked "Simpan urutan". Leaving
/// with unsaved changes asks "Simpan perubahan?". Outside draft the list is
/// read-only under "Urutan dikunci setelah arisan dimulai".
class const FixedOrderPage({super.key, required final String groupId, required final VoidCallback onDone})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = fixedOrderControllerProvider(groupId);
    final dirty = ref.watch(provider.select((s) => s.value?.dirty ?? false));
    final loaded = ref.watch(provider.select((s) => s.hasValue));
    final group = ref.watch(groupDetailControllerProvider(groupId).select((s) => s.value?.group));
    final total = group?.totalSlots ?? 0;

    Future<bool> save() async {
      final failure = await ref.read(provider.notifier).save(total);
      if (!context.mounted) return false;
      showAppToast(context, failure?.displayMessage(context.l10n) ?? l10n.fixedOrderSaved);
      return failure == null;
    }

    Future<void> confirmLeave() async {
      final keep = await showAppDialog(
        context,
        title: l10n.fixedOrderUnsavedTitle,
        confirmLabel: l10n.saveButton,
        cancelLabel: l10n.fixedOrderDiscard,
        destructive: false,
      );
      if (!context.mounted) return;
      if (keep && !await save()) return;
      if (context.mounted) onDone();
    }

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) confirmLeave();
      },
      child: Scaffold(
        appBar: AppTopBar(),
        body: loaded && group != null
            ? _FixedOrderBody(
                groupId: groupId,
                locked: group.status != GroupStatus.draft,
                totalSlots: total,
                onSave: save,
              )
            : const Center(child: CircularProgressIndicator.adaptive()),
      ),
    );
  }
}

class const _FixedOrderBody({
  required final String groupId,
  required final bool locked,
  required final int totalSlots,
  required final Future<bool> Function() onSave,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final provider = fixedOrderControllerProvider(groupId);
    final order = ref.watch(provider.select((s) => s.value?.order ?? const <Member>[]));
    final saving = ref.watch(provider.select((s) => s.value?.saving ?? false));
    final incomplete = order.length < totalSlots;
    final margin = context.screenMargin;
    final notifier = ref.watch(provider.notifier);

    void move(int from, int to) {
      HapticFeedback.selectionClick();
      notifier.move(from, to);
    }

    void shuffle() {
      final previous = notifier.shuffle();
      if (previous == null) return;
      showAppToast(
        context,
        l10n.fixedOrderShuffled,
        actionLabel: l10n.fixedOrderUndo,
        onAction: () => notifier.restore(previous),
      );
    }

    return MaxWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(margin, AppSpace.s2, margin, AppSpace.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HeadlineText(l10n.fixedOrderHeadline),
                const SizedBox(height: AppSpace.s2),
                if (locked)
                  AppBanner(message: l10n.fixedOrderLocked, icon: AppIcons.lockSimple)
                else ...[
                  Text(l10n.fixedOrderHelp, style: t.body.copyWith(color: c.textSecondary)),
                  if (incomplete) ...[
                    const SizedBox(height: AppSpace.s3),
                    AppBanner(message: l10n.fixedOrderIncomplete, variant: AppBannerVariant.warning),
                  ],
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AppButton.ghost(label: l10n.fixedOrderShuffle, icon: AppIcons.shuffle, onPressed: shuffle),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: locked
                ? ListView.separated(
                    padding: EdgeInsets.fromLTRB(margin, 0, margin, AppSpace.s8),
                    itemCount: order.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s2),
                    itemBuilder: (context, i) => _Row(member: order[i], position: i + 1, locked: true),
                  )
                : ReorderableListView.builder(
                    padding: EdgeInsets.fromLTRB(margin, 0, margin, AppSpace.s4),
                    buildDefaultDragHandles: false,
                    itemCount: order.length,
                    proxyDecorator: (child, _, animation) => ScaleTransition(
                      scale: Tween<double>(begin: 1, end: 1.02).animate(animation),
                      child: Material(elevation: 6, borderRadius: BorderRadius.circular(AppRadius.lg), child: child),
                    ),
                    onReorderItem: move,
                    itemBuilder: (context, i) => Padding(
                      key: ValueKey(order[i].id),
                      padding: const EdgeInsets.only(bottom: AppSpace.s2),
                      child: _Row(
                        member: order[i],
                        position: i + 1,
                        index: i,
                        onMoveUp: i == 0 ? null : () => move(i, i - 1),
                        onMoveDown: i == order.length - 1 ? null : () => move(i, i + 1),
                      ),
                    ),
                  ),
          ),
          if (!locked)
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(margin, AppSpace.s2, margin, AppSpace.s4),
                child: AppButton(
                  label: l10n.fixedOrderSave,
                  block: true,
                  loading: saving,
                  onPressed: incomplete ? null : onSave,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class const _Row({
  required final Member member,
  required final int position,
  final int? index,
  final bool locked = false,
  final VoidCallback? onMoveUp,
  final VoidCallback? onMoveDown,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ReorderableMemberRow(
    position: position,
    name: member.displayName ?? '',
    slotNo: member.slotNo ?? 0,
    avatarUrl: member.avatarUrl,
    guest: member.isGuest ?? false,
    dragIndex: index,
    locked: locked,
    onMoveUp: onMoveUp,
    onMoveDown: onMoveDown,
  );
}
