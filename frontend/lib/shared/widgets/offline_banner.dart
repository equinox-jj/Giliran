import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/utils/date_formatter.dart';
import 'app_banner.dart';

/// Top-of-screen notice that the app is showing cached data (§12), with the
/// Jakarta time of the last successful sync when there was one.
class const OfflineBanner({super.key, required final DateTime? lastSyncedAt}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final synced = lastSyncedAt;

    return AppBanner(
      variant: AppBannerVariant.offline,
      compact: true,
      message: synced == null
          ? context.l10n.offlineBanner
          : context.l10n.offlineBannerSynced(AppDate.time(AppDate.jakarta(synced))),
    );
  }
}
