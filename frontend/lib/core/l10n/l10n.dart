import 'package:material_ui/material_ui.dart';

import 'gen/app_localizations.dart';

export 'gen/app_localizations.dart';

/// Delegates for every `MaterialApp`: the app strings plus the
/// `material_ui` / `cupertino_ui` ones.
///
/// Use this instead of `AppLocalizations.localizationsDelegates`. The
/// generated list carries `flutter_localizations` delegates, which only
/// translate the `package:flutter/material.dart` types, not the
/// `material_ui` ones this app uses.
const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];

/// Short access to the generated strings: `context.l10n.appName`.
extension AppL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
