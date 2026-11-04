import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/l10n/l10n.dart';
import '../../core/themes/themes.dart';
import '../../core/utils/code_formatter.dart';
import '../../core/utils/date_formatter.dart';
import 'pressable.dart';

/// The Bukti Kocok ticket (Tikar §9.7): the shareable proof of a draw.
/// Kunyit body with ink text and a cream stub in **both** themes, so the
/// exported image looks the same everywhere; 16 px notches and a dashed
/// perforation between them; the stub carries the grouped verification code
/// and a QR of [verifyUrl]. Exported at 1080 × 1350 through
/// `WidgetImageExporter` (wrap it in [BuktiKocokExportFrame]).
class const BuktiKocokTicket({
  super.key,
  required final String groupName,
  required final int periodNo,
  required final int totalPeriods,
  required final int slotNo,
  required final String winnerName,

  /// The draw instant (UTC); shown in Jakarta time.
  required final DateTime drawnAt,
  required final String code,
  required final String verifyUrl,
  final VoidCallback? onTap,
}) extends StatelessWidget {
  /// Diameter of each perforation notch.
  static const notch = 16.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final t = AppTextStyles.of(context);
    final at = AppDate.jakarta(drawnAt);
    final date = '${AppDate.full(at)} · ${AppDate.time(at)}';
    final ink = c.ink;
    final ticket = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: c.ticketBody,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.s5, AppSpace.s5, AppSpace.s5, AppSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          groupName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.micro.copyWith(color: ink),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s3),
                      Text('P$periodNo / $totalPeriods', style: t.micro.copyWith(color: ink)),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(l10n.ticketNo(CodeFormatter.slotNo(slotNo)), style: t.display.copyWith(color: ink)),
                  Text(winnerName, style: t.titleLg.copyWith(color: ink)),
                  const SizedBox(height: AppSpace.s2),
                  Text(date, style: t.caption.copyWith(color: ink)),
                ],
              ),
            ),
          ),
          _Perforation(body: c.ticketBody, stub: c.ticketStub, ink: ink),
          ColoredBox(
            color: c.ticketStub,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.s5, AppSpace.s3, AppSpace.s5, AppSpace.s5),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.ticketCode, style: t.micro.copyWith(color: ink)),
                        const SizedBox(height: AppSpace.s1),
                        Text(CodeFormatter.grouped(code), style: t.mono.copyWith(color: ink)),
                        const SizedBox(height: AppSpace.s2),
                        Text(l10n.ticketCheckAt, style: t.caption.copyWith(color: ink)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.s3),
                  QrImageView(
                    data: verifyUrl,
                    size: 72,
                    padding: EdgeInsets.zero,
                    backgroundColor: c.ticketStub,
                    eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: ink),
                    dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: ink),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      label: l10n.ticketSemantics(
        groupName,
        periodNo,
        totalPeriods,
        CodeFormatter.slotNo(slotNo),
        winnerName,
        date,
        CodeFormatter.grouped(code),
      ),
      excludeSemantics: true,
      child: onTap == null ? ticket : Pressable(onTap: onTap, shape: AppShapes.squircle(AppRadius.lg), child: ticket),
    );
  }
}

/// The 4:5 frame the ticket is exported in: 360 × 450 logical px on the
/// stub cream, rendered at pixel ratio 3 for a 1080 × 1350 PNG.
class const BuktiKocokExportFrame({super.key, required final Widget ticket}) extends StatelessWidget {
  static const size = Size(360, 450);
  static const pixelRatio = 3.0;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: size,
    child: ColoredBox(
      color: context.colors.ticketStub,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s5),
        child: Center(child: ticket),
      ),
    ),
  );
}

/// The perforation between body and stub: notches cut at both edges and a
/// dashed ink line between them.
class const _Perforation({required final Color body, required final Color stub, required final Color ink})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const _NotchClipper(),
    child: CustomPaint(
      size: const Size.fromHeight(BuktiKocokTicket.notch),
      painter: _PerforationPainter(body: body, stub: stub, ink: ink),
    ),
  );
}

class const _NotchClipper() extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const r = BuktiKocokTicket.notch / 2;
    final y = size.height / 2;
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, y), radius: r))
      ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: r));
    return Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), holes);
  }

  @override
  bool shouldReclip(_NotchClipper oldClipper) => false;
}

class const _PerforationPainter({required final Color body, required final Color stub, required final Color ink})
    extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    canvas
      ..drawRect(Rect.fromLTWH(0, 0, size.width, mid), Paint()..color = body)
      ..drawRect(Rect.fromLTWH(0, mid, size.width, size.height - mid), Paint()..color = stub);
    final dash = Paint()
      ..color = ink
      ..strokeWidth = 1.5;
    const start = BuktiKocokTicket.notch / 2 + 4;
    for (var x = start; x < size.width - start; x += 10) {
      canvas.drawLine(Offset(x, mid), Offset((x + 6).clamp(0, size.width - start), mid), dash);
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter old) => old.body != body || old.stub != stub || old.ink != ink;
}
