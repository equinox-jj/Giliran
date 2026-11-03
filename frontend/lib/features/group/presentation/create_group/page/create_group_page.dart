import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/enums/period_type.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../controllers/create_group_controller.dart';
import '../widgets/basics_step.dart';
import '../widgets/schedule_step.dart';
import '../widgets/summary_card.dart';

/// Create group (S13 → S14), a full-screen modal. Back on step 2 returns to
/// step 1 with the values kept. [onCreated] gets the new group's id.
class const CreateGroupPage({
  super.key,
  required final ValueChanged<String> onCreated,
  final int? prefillAmount,
  final PeriodType? prefillPeriodType,
  final int? prefillTotalSlots,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState() extends ConsumerState<CreateGroupPage> {
  late final CreateGroupControllerProvider _provider;
  late final TextEditingController _name;
  late final TextEditingController _amount;

  @override
  void initState() {
    super.initState();
    _provider = createGroupControllerProvider(
      prefillAmount: widget.prefillAmount,
      prefillPeriodType: widget.prefillPeriodType,
      prefillTotalSlots: widget.prefillTotalSlots,
    );
    _name = TextEditingController();
    final amount = widget.prefillAmount;
    _amount = TextEditingController(text: amount == null ? '' : Rupiah.digits(amount));
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final group = await ref.read(_provider.notifier).submit();
    if (!mounted) return;
    if (group != null) {
      widget.onCreated(group.id ?? '');
      return;
    }
    final failure = ref.read(_provider).failure;
    if (failure != null && failure is! ValidationFailure) showAppToast(context, failure.displayMessage);
  }

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(_provider.select((d) => d.step));
    return PopScope(
      canPop: step == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(_provider.notifier).editBasics();
      },
      child: Scaffold(
        appBar: _StepTopBar(step: step, onBack: ref.read(_provider.notifier).editBasics),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(context.screenMargin, AppSpace.s4, context.screenMargin, AppSpace.s6),
                  children: [
                    MaxWidth(
                      child: step == 1
                          ? BasicsStep(provider: _provider, nameController: _name, amountController: _amount)
                          : ScheduleStep(provider: _provider),
                    ),
                  ],
                ),
              ),
              _BottomAction(provider: _provider, onSubmit: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

/// The S13/S14 top bar: close (step 1) or back (step 2) beside the
/// "1 dari 2" step bar, with no title.
class const _StepTopBar({required final int step, required final VoidCallback onBack})
    extends StatelessWidget
    implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.topBarH);

  @override
  Widget build(BuildContext context) {
    final first = step == 1;
    return Material(
      color: context.colors.page,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AppSizes.topBarH,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.screenMargin),
            child: MaxWidth(
              child: Row(
                children: [
                  CircleIconButton(
                    icon: first ? AppIcons.x : AppIcons.arrowLeft,
                    semanticLabel: first ? 'Tutup' : 'Kembali',
                    onPressed: first ? () => Navigator.of(context).maybePop() : onBack,
                  ),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(child: StepProgressBar(step: step, total: 2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pinned under the form: on step 1 the "Total per periode" bar above
/// "Lanjut"; on step 2 "Buat grup".
class const _BottomAction({required final CreateGroupControllerProvider provider, required final VoidCallback onSubmit})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final draft = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final step1 = draft.step == 1;
    final ready = step1 ? controller.basicsErrors.isEmpty : draft.startDate != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(context.screenMargin, AppSpace.s3, context.screenMargin, AppSpace.s4),
      child: MaxWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (step1) ...[
              SummaryCard(potAmount: draft.potAmount),
              const SizedBox(height: AppSpace.s3),
            ],
            AppButton(
              label: step1 ? l10n.nextButton : l10n.createGroupSubmit,
              block: true,
              loading: draft.submitting,
              onPressed: !ready ? null : (step1 ? controller.next : onSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
