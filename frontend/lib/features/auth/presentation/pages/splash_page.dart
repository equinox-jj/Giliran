import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_illustrations.dart';
import '../../../../core/themes/themes.dart';
import '../../../../shared/widgets/widgets.dart';

/// S01 launch gate: the kaleng and wordmark on `bg.page`, held for [hold],
/// then [onReady] picks the next route.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.onReady, this.hold = minHold});

  /// Long enough to read the wordmark, short enough not to feel like a wait.
  static const minHold = Duration(milliseconds: 900);

  /// Matches the native splash image (288 px at xxxhdpi).
  static const kalengSize = 72.0;

  final VoidCallback onReady;
  final Duration hold;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.hold, () {
      if (mounted) widget.onReady();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Scaffold(
      backgroundColor: c.page,
      body: Semantics(
        label: 'Giliran sedang dibuka',
        child: ExcludeSemantics(
          child: Stack(
            children: [
              // The kaleng sits at the exact screen center, like the native
              // splash (flutter_native_splash.yaml), so the hand-off does not
              // jump; the wordmark hangs below it.
              Center(
                child: SizedBox.square(
                  dimension: SplashPage.kalengSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      const Illustration(
                        AppIllustrations.splashKaleng,
                        width: SplashPage.kalengSize,
                        height: SplashPage.kalengSize,
                      ),
                      Positioned(
                        top: SplashPage.kalengSize + 14,
                        child: Text(
                          'giliran',
                          maxLines: 1,
                          softWrap: false,
                          style: t.display.copyWith(
                            fontSize: 32,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpace.s10,
                child: SafeArea(
                  top: false,
                  child: Text(
                    'Arisan yang transparan',
                    textAlign: TextAlign.center,
                    style: t.caption.copyWith(color: c.textTertiary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
