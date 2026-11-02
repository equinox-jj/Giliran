import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/themes/themes.dart';
import '../app_button.dart';
import 'app_sheet.dart';

/// Platform date picker: the themed Material picker on Android, a
/// `CupertinoDatePicker` in a sheet on iOS.
abstract final class AppDatePicker {
  /// Shows the platform date picker and returns the chosen date, or `null` when
  /// it is dismissed.
  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    String? helpText,
  }) {
    final platform = Theme.of(context).platform;
    if (platform != TargetPlatform.iOS && platform != TargetPlatform.macOS) {
      return showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        helpText: helpText,
      );
    }

    var selected = initialDate;
    return showAppSheet<DateTime>(
      context,
      builder: (context) => AppSheetBody(
        title: helpText,
        scrollable: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 216,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Theme.of(context).brightness,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: AppTextStyles.of(
                      context,
                    ).title.copyWith(color: context.colors.textPrimary),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  minimumDate: firstDate,
                  maximumDate: lastDate,
                  onDateTimeChanged: (d) => selected = d,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            AppButton(
              label: 'Selesai',
              block: true,
              onPressed: () => Navigator.of(context).pop(selected),
            ),
          ],
        ),
      ),
    );
  }
}
