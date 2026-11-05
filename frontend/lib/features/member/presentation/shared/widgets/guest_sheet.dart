import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/error/failure_message.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/themes/themes.dart';
import '../../../../../core/utils/code_formatter.dart';
import '../../../../../core/utils/enums/api_error_code.dart';
import '../../../../../core/utils/phone_formatter.dart';
import '../../../../../shared/widgets/widgets.dart';
import '../../../domain/entities/member.dart';
import '../../../domain/entities/member_input.dart';
import '../controllers/guest_controller.dart';

/// Opens Add / edit guest (S27). Adds a guest to [slotNo] (null when the
/// group is full), or edits [guest]. Resolves to the saved member.
Future<Member?> showGuestSheet(
  BuildContext context, {
  required String groupId,
  int? slotNo,
  Member? guest,
}) => showAppSheet<Member>(
  context,
  builder: (_) => GuestSheet(groupId: groupId, slotNo: slotNo, guest: guest),
);

/// The guest form: name, optional phone ("untuk pengingat WhatsApp") and
/// "Tambahkan ke slot {n}". A full group, or a `group_full` answer, shows
/// "Semua slot sudah terisi." and disables the button.
class const GuestSheet({super.key, required final String groupId, final int? slotNo, final Member? guest})
    extends ConsumerStatefulWidget {
  @override
  ConsumerState<GuestSheet> createState() => _GuestSheetState();
}

class _GuestSheetState() extends ConsumerState<GuestSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  var _nameError = false;

  bool get _editing => widget.guest != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.guest?.displayName ?? '');
    final phone = widget.guest?.guestPhone;
    _phone = TextEditingController(text: phone == null ? '' : PhoneFormatter.localPart(phone));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final notifier = ref.read(guestControllerProvider(widget.groupId).notifier);
    final phone = PhoneField.e164(_phone.text);
    final guest = widget.guest;
    final saved = guest == null
        ? await notifier.add(GuestInput(name: _name.text, phone: phone))
        : await notifier.update(
            guest.id ?? '',
            UpdateGuestInput(
              name: _name.text.trim() == guest.displayName ? null : _name.text,
              phone: phone == guest.guestPhone ? null : phone,
              clearPhone: phone == null && guest.guestPhone != null,
            ),
          );
    if (!mounted) return;
    if (saved != null) {
      Navigator.of(context).pop(saved);
      return;
    }
    final failure = ref.read(guestControllerProvider(widget.groupId)).failure;
    setState(() => _nameError = failure?.fieldMessage('name') != null);
    if (failure != null && failure is! ValidationFailure && failure.apiCode != ApiErrorCode.groupFull) {
      showAppToast(context, failure.displayMessage(context.l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final state = ref.watch(guestControllerProvider(widget.groupId));
    final full = !_editing && (widget.slotNo == null || state.failure?.apiCode == ApiErrorCode.groupFull);
    final slot = widget.slotNo;
    return AppSheetBody(
      title: _editing ? l10n.guestEditTitle : l10n.guestSheetTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.guestSheetHelp, style: t.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpace.s4),
          AppTextField(
            controller: _name,
            label: l10n.guestNameLabel,
            autofocus: !_editing,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            errorText: _nameError ? l10n.guestNameError : null,
            onChanged: (_) {
              if (_nameError) setState(() => _nameError = false);
            },
          ),
          const SizedBox(height: AppSpace.s4),
          PhoneField(
            controller: _phone,
            label: l10n.guestPhoneLabel,
            helper: l10n.guestPhoneHelper,
          ),
          if (full) ...[
            const SizedBox(height: AppSpace.s4),
            AppBanner(message: l10n.guestFull, variant: AppBannerVariant.warning, compact: true),
          ],
          const SizedBox(height: AppSpace.s6),
          AppButton(
            label: _editing
                ? l10n.guestSaveButton
                : l10n.guestAddButton(slot == null ? '' : CodeFormatter.slotNo(slot)),
            block: true,
            loading: state.saving,
            onPressed: full ? null : _save,
          ),
        ],
      ),
    );
  }
}
