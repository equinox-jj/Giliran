import 'package:material_ui/material_ui.dart';

import '../core/constants/app_doodles.dart';
import '../core/constants/app_icons.dart';
import '../core/constants/app_illustrations.dart';
import '../core/themes/themes.dart';
import '../core/utils/enums/group_status.dart';
import '../core/utils/enums/member_role.dart';
import '../core/utils/enums/payment_status.dart';
import '../core/utils/enums/period_type.dart';
import '../features/auth/presentation/welcome/page/welcome_page.dart';
import '../features/group/domain/entities/group.dart';
import '../features/group/domain/entities/group_summary.dart';
import '../features/home/domain/entities/agenda_day.dart';
import '../shared/widgets/widgets.dart';
import 'routes.dart';

/// Debug gallery of the Tikar components in light and dark, used to compare
/// against the design system previews. Remove once real screens exist.
class const ComponentGalleryPage({super.key}) extends StatefulWidget {
  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState() extends State<ComponentGalleryPage> {
  bool? _dark;

  @override
  Widget build(BuildContext context) {
    final platformDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final dark = _dark ?? platformDark;
    return Theme(
      data: dark ? AppTheme.dark() : AppTheme.light(),
      child: _Gallery(
        dark: dark,
        onToggleTheme: () => setState(() => _dark = !dark),
      ),
    );
  }
}

const _gap = SizedBox(height: AppSpace.s3);

class const _Gallery({required final bool dark, required final VoidCallback onToggleTheme}) extends StatefulWidget {
  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState() extends State<_Gallery> {
  static const _sections = [
    _HeroSection(),
    _GroupsSection(),
    _ButtonsSection(),
    _StatusSection(),
    _ChipsSection(),
    _InputsSection(),
    _CodeSection(),
    _EmailCodeSection(),
    _PeopleSection(),
    _ListsSection(),
    _PaymentsSection(),
    _DoodlesSection(),
    _OnboardingSection(),
    _CardsSection(),
    _ScreensSection(),
  ];

  int _nav = 0;

  @override
  Widget build(BuildContext context) {
    return AppNavShell(
      selectedIndex: _nav,
      onSelected: (i) => setState(() => _nav = i),
      body: Scaffold(
        appBar: AppTopBar(
          title: 'Tikar',
          collapseTitle: true,
          showBack: false,
          actions: [
            CircleIconButton(
              icon: widget.dark ? AppIcons.eye : AppIcons.eyeSlash,
              semanticLabel: 'Ganti tema',
              onPressed: widget.onToggleTheme,
            ),
            OverflowMenuButton(
              items: [
                OverflowMenuItem(
                  label: 'Edit grup',
                  icon: AppIcons.pencilSimple,
                  onSelected: () => showAppToast(context, 'Edit grup'),
                ),
                OverflowMenuItem(
                  label: 'Bagikan',
                  icon: AppIcons.shareNetwork,
                  onSelected: () => showAppToast(context, 'Bagikan'),
                ),
                OverflowMenuItem(
                  label: 'Tutup grup',
                  icon: AppIcons.trash,
                  destructive: true,
                  onSelected: () => showAppDialog(
                    context,
                    title: 'Tutup Arisan RT 05?',
                    message: 'Grup jadi arsip dan tidak bisa dibuka lagi.',
                    confirmLabel: 'Tutup grup',
                  ),
                ),
              ],
            ),
          ],
        ),
        body: ListView.builder(
          padding: EdgeInsets.fromLTRB(
            context.screenMargin,
            0,
            context.screenMargin,
            context.isCompact ? AppBottomNavBar.contentInset(context) : AppSpace.s8,
          ),
          itemCount: _sections.length,
          itemBuilder: (context, i) => MaxWidth(child: _sections[i]),
        ),
      ),
    );
  }
}

class const _HeroSection() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HeadlineBlock(
          'Periode 4 dari 10, **8 orang sudah bayar**.',
        ),
        HeroPanel(
          decoration: const Doodle(AppDoodles.kaleng),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Arisan RT 05',
                style: t.titleLg.copyWith(color: c.textPrimary),
              ),
              Text(
                'Periode 4 dari 10',
                style: t.body.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: AppSpace.s4),
              Text.rich(
                Rupiah.span(
                  1600000,
                  t.amountXl.copyWith(color: c.textPrimary),
                ),
              ),
              Text(
                'dari ${Rupiah.format(2000000)}',
                style: t.body.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: AppSpace.s4),
              Wrap(
                spacing: AppSpace.s2,
                runSpacing: AppSpace.s2,
                children: [
                  AppButton(
                    label: 'Tinjau 2 bukti',
                    icon: AppIcons.receipt,
                    onPressed: () {},
                  ),
                  AppButton.tonal(
                    label: 'Lihat jadwal',
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Group signature components: Giliran Ring and Group Card.
class const _GroupsSection() extends StatelessWidget {
  static const _active = GroupSummary(
    id: 'g-gallery-1',
    name: 'Arisan RT 05',
    amount: 200000,
    periodType: PeriodType.monthly,
    status: GroupStatus.active,
    myRole: MemberRole.organizer,
    totalSlots: 10,
    filledSlots: 10,
    currentPeriodNo: 4,
    myPaymentStatus: PaymentStatus.pendingReview,
    pendingReviewCount: 2,
  );

  static const _draft = GroupSummary(
    id: 'g-gallery-2',
    name: 'Arisan Kantor',
    amount: 500000,
    periodType: PeriodType.weekly,
    status: GroupStatus.draft,
    myRole: MemberRole.member,
    totalSlots: 10,
    filledSlots: 8,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Groups'),
        const BankAccountCard(
          info: PaymentInfo(bankName: 'BCA', accountNumber: '1234567890', accountHolder: 'Rina Wulandari'),
        ),
        _gap,
        QrisCard(onUpload: () => showAppToast(context, 'Upload QRIS')),
        _gap,
        const ObligationMeter(
          name: 'Pak Dedi',
          wonPeriodNo: 3,
          periodsAfterWin: 7,
          remainingCount: 5,
          remainingAmount: 1000000,
          overdueCount: 1,
          overdueAmount: 200000,
          showOverdue: true,
        ),
        _gap,
        const ReorderableMemberRow(position: 1, name: 'Bu Rina', slotNo: 4),
        _gap,
        const ReorderableMemberRow(position: 2, name: 'Pak Dedi', slotNo: 7, guest: true, locked: true),
        _gap,
        ReadinessChecklist(
          rows: [
            const ReadinessRow(title: 'Semua slot terisi', caption: '10 dari 10 slot terisi', done: true),
            ReadinessRow(
              title: 'Info rekening ada',
              caption: 'Anggota perlu tahu ke mana transfer.',
              done: false,
              highlighted: true,
              actionLabel: 'Isi rekening',
              onAction: () => showAppToast(context, 'Isi rekening'),
            ),
          ],
        ),
        _gap,
        DrawStage(
          tone: c.toneFor('g-gallery-1'),
          people: [for (var n = 1; n <= 8; n++) AvatarData(name: 'Anggota $n')],
          commitmentHash: '9f2c4b1e7d3a8c6f0e5b2a9d4c7f1e3b8a6d2c5f9e0b7a4d1c8f3e6b2a5d9c7e',
          onCommitmentTap: () => showAppToast(context, 'Kode komitmen'),
          onDraw: () => showAppToast(context, 'Kocok'),
          onPeople: () {},
          onHelp: () {},
        ),
        _gap,
        BuktiKocokTicket(
          groupName: 'Arisan RT 05',
          periodNo: 4,
          totalPeriods: 10,
          slotNo: 7,
          winnerName: 'Bu Rina',
          drawnAt: DateTime.utc(2026, 10, 26, 12, 30),
          code: '7H2K9QX4MP',
          verifyUrl: 'https://giliran.monai.my.id/v/7H2K9QX4MP',
          onTap: () => showAppToast(context, 'Cek keaslian'),
        ),
        _gap,
        PeriodStrip(
          periods: [
            for (var n = 1; n <= 10; n++)
              PeriodTokenData(
                id: 'p$n',
                periodNo: n,
                state: n < 4 ? SlotTokenState.done : (n == 4 ? SlotTokenState.current : SlotTokenState.upcoming),
                winnerName: n < 4 ? 'Anggota $n' : null,
                iWon: n == 2,
              ),
          ],
          onSelect: (_) {},
        ),
        _gap,
        JadwalTimeline(
          todayAt: 0.45,
          todayLabel: '40%',
          bars: [
            for (var n = 1; n <= 10; n++)
              JadwalBar(
                periodNo: n,
                start: (n - 1) / 10,
                end: n / 10,
                fill: n <= 4 ? JadwalBarFill.drawn : (n == 5 ? JadwalBarFill.open : JadwalBarFill.upcoming),
                tone: n <= 4 ? c.tones[n % c.tones.length].accent : null,
                label: n <= 4 ? 'P$n · Anggota $n' : 'P$n',
                semanticsLabel: 'Periode $n',
              ),
          ],
        ),
        _gap,
        CycleSummaryCard(
          tone: c.tones[0],
          headline: 'Arisan selesai. **10 periode, 10 pemenang.**',
          stats: const [
            CycleStat(value: 'Rp20.000.000', label: 'Terkumpul'),
            CycleStat(value: '96%', label: 'Iuran lunas'),
            CycleStat(value: '10', label: 'Anggota'),
          ],
          tokens: [
            for (var n = 1; n <= 10; n++)
              PeriodTokenData(
                id: 'p$n',
                periodNo: n,
                state: n <= 8 ? SlotTokenState.done : SlotTokenState.upcoming,
                winnerName: n <= 8 ? 'Anggota $n' : null,
              ),
          ],
          winners: const [
            CycleWinnerRow(periodId: 'p1', title: 'P1 · Anggota 1', date: 'Sen, 5 Jan'),
            CycleWinnerRow(periodId: 'p2', title: 'P2 · Anggota 2', date: 'Kam, 5 Feb'),
          ],
          onProof: (_) => showAppToast(context, 'Bukti Kocok'),
        ),
        _gap,
        AspectRatio(
          aspectRatio: 4 / 5,
          child: FittedBox(
            child: RecapExportFrame(
              card: RecapCard(
                groupName: 'Arisan RT 05',
                periodNo: 4,
                totalPeriods: 10,
                paidCount: 8,
                totalCount: 10,
                collectedAmount: 1600000,
                expectedAmount: 2000000,
                unpaidNames: const ['Pak Dedi', 'Bu Ani'],
                dueDate: DateTime.utc(2026, 10, 25),
                drawDate: DateTime.utc(2026, 10, 26),
                account: 'BCA 1234567890 a.n. Rina',
                tone: GiliranColors.exportTones[0],
              ),
            ),
          ),
        ),
        _gap,
        CurrentPeriodHero(
          title: 'Arisan RT 05',
          subtitle: 'Periode 4 dari 10',
          ringValue: 8,
          ringTotal: 10,
          ringPending: 1,
          ringSemantics: '8 dari 10 anggota sudah bayar, 1 menunggu dicek',
          amount: 1600000,
          amountCaption: 'dari Rp2.000.000',
          infoLine: 'Jatuh tempo Sab, 25 Okt · Kocok Sab, 25 Okt',
          tone: c.tones[0],
          action: CurrentPeriodHeroAction(label: 'Tinjau 1 bukti', onPressed: () => showAppToast(context, 'Tinjau')),
        ),
        _gap,
        const StepProgressBar(step: 1, total: 2),
        _gap,
        AgendaStrip(
          days: [
            for (var i = 0; i < 7; i++)
              AgendaDay(
                date: DateTime.utc(2026, 11, 2 + i),
                isToday: i == 2,
                events: [
                  if (i == 3) const AgendaEvent(kind: AgendaEventKind.due, groupId: 'g1', groupName: 'Arisan RT 05'),
                  if (i == 5) const AgendaEvent(kind: AgendaEventKind.draw, groupId: 'g1', groupName: 'Arisan RT 05'),
                ],
              ),
          ],
          selectedIndex: 3,
          onSelect: (_) {},
        ),
        _gap,
        Wrap(
          spacing: AppSpace.s4,
          runSpacing: AppSpace.s4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const GiliranRing(
              value: 8,
              total: 10,
              pending: 1,
              size: GiliranRingSize.s96,
              caption: 'sudah bayar',
              semanticsLabel: '8 dari 10 anggota sudah bayar, 1 menunggu dicek',
            ),
            GiliranRing(
              value: 4,
              total: 10,
              size: GiliranRingSize.s64,
              color: c.tones[1].accent,
              semanticsLabel: 'Periode 4 dari 10',
            ),
            const GiliranRing(
              value: 10,
              total: 10,
              size: GiliranRingSize.s48,
              semanticsLabel: '10 dari 10 anggota sudah bayar',
            ),
            const GiliranRing(
              value: 3,
              total: 10,
              size: GiliranRingSize.s120,
              caption: 'sudah bayar',
              semanticsLabel: '3 dari 10 anggota sudah bayar',
            ),
          ],
        ),
        _gap,
        SizedBox(
          height: GroupCard.carouselHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 2,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s3),
            itemBuilder: (context, i) => GroupCard(
              group: i == 0 ? _active : _draft,
              onTap: () => showAppToast(context, 'Buka grup'),
            ),
          ),
        ),
        _gap,
        GroupCard(group: _active, layout: GroupCardLayout.list, onTap: () => showAppToast(context, 'Buka grup')),
      ],
    );
  }
}

class const _ButtonsSection() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Buttons'),
        AppButton(
          label: 'Upload bukti',
          icon: AppIcons.uploadSimple,
          block: true,
          onPressed: () => showAppToast(
            context,
            'Bukti terkirim.',
            actionLabel: 'Batal',
          ),
        ),
        _gap,
        AppButton.secondary(
          label: 'Kirim pengingat',
          icon: AppIcons.bellRinging,
          block: true,
          onPressed: () {},
        ),
        _gap,
        const AppButton(
          label: 'Mulai arisan',
          block: true,
          onPressed: null,
          disabledReason: 'Lengkapi 2 hal lagi',
        ),
        _gap,
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppButton(
              label: 'Simpan',
              loading: true,
              onPressed: () {},
            ),
            AppButton.ghost(label: 'Batal', onPressed: () {}),
            AppButton.link(label: 'Lupa PIN?', onPressed: () {}),
            AppButton.destructive(
              label: 'Hapus akun',
              onPressed: () {},
            ),
            AppButton.secondary(
              label: 'Salin',
              size: AppButtonSize.xsmall,
              onPressed: () {},
            ),
          ],
        ),
        _gap,
        Row(
          children: [
            CircleIconButton(
              icon: AppIcons.arrowLeft,
              semanticLabel: 'Kembali',
              onPressed: () {},
            ),
            CircleIconButton(
              icon: AppIcons.bellSimple,
              semanticLabel: 'Notifikasi, 3 belum dibaca',
              showDot: true,
              onPressed: () {},
            ),
            CircleIconButton.ink(
              icon: AppIcons.caretRightBold,
              semanticLabel: 'Tinjau',
              onPressed: () {},
            ),
            const SizedBox(width: AppSpace.s2),
            CircleIconButton.draw(
              icon: AppIcons.shuffleBold,
              semanticLabel: 'Kocok',
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }
}

class const _StatusSection() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Status'),
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          children: [
            for (final s in ChipStatus.values) StatusChip(s),
          ],
        ),
        _gap,
        const Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CountDot(),
            CountBadge(3),
            CountBadge(12),
            LabelBadge('Tamu'),
            LabelBadge('Pengurus'),
            LabelBadge('Kamu'),
          ],
        ),
        _gap,
        const AppBanner(
          message: 'Grup belum dimulai. 8 dari 10 slot terisi.',
        ),
        _gap,
        AppBanner(
          variant: AppBannerVariant.warning,
          message: 'Kocokan besok, 2 orang belum bayar.',
          actionLabel: 'Ingatkan',
          onAction: () {},
        ),
        _gap,
        const AppBanner(
          variant: AppBannerVariant.error,
          message: 'Bukti kamu ditolak. Upload lagi.',
        ),
        _gap,
        OfflineBanner(lastSyncedAt: DateTime.utc(2026, 11, 3, 12, 2)),
        _gap,
        AppBanner(
          variant: AppBannerVariant.success,
          message: 'Semua sudah bayar periode ini.',
          onDismiss: () {},
        ),
        _gap,
        const AppBanner(
          note: true,
          icon: AppIcons.shieldCheck,
          message: 'Email kamu hanya untuk masuk dan pemulihan akun. Tidak ditampilkan ke anggota lain.',
        ),
        _gap,
        const AppBanner(
          compact: true,
          message: 'Hindari angka berurutan atau sama semua, seperti 123456.',
        ),
      ],
    );
  }
}

class const _PeopleSection() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'People'),
        Row(
          children: [
            const AppAvatar(name: 'Rina Wulandari', organizer: true),
            const SizedBox(width: AppSpace.s3),
            AppAvatar(
              name: 'Pak Dedi',
              tone: c.tones[1],
              size: AppSizes.avatarLg,
            ),
            const SizedBox(width: AppSpace.s3),
            const AppAvatar(name: 'Bu Ani', guest: true),
            const SizedBox(width: AppSpace.s3),
            const AvatarStack(
              people: [
                AvatarData(name: 'Rina W'),
                AvatarData(name: 'Dedi S'),
                AvatarData(name: 'Ani P'),
                AvatarData(name: 'Budi'),
                AvatarData(name: 'Sari'),
                AvatarData(name: 'Tono'),
              ],
            ),
          ],
        ),
        _gap,
        Wrap(
          spacing: AppSpace.s6,
          runSpacing: AppSpace.s4,
          children: [
            AvatarPicker(onTap: () => showAvatarSourceSheet(context)),
            const AvatarPicker(progress: 0.42, onTap: null),
            AvatarPicker(
              errorText: 'Foto lebih dari 5 MB.',
              onTap: () => showAvatarSourceSheet(context, canRemove: true),
              onRetry: () {},
            ),
          ],
        ),
        _gap,
        AppListRow(
          title: 'Kamu',
          subtitle: 'Jatuh tempo Sab, 25 Okt',
          inverse: true,
          leading: const AppAvatar(name: 'Joshua J', size: 40),
          trailing: CircleIconButton.cream(
            icon: AppIcons.uploadSimple,
            semanticLabel: 'Upload bukti',
            onPressed: () {},
          ),
          onTap: () {},
        ),
        const SizedBox(height: AppSpace.s2),
        const AppListRow(
          title: 'Pak Dedi',
          subtitle: 'Upload 24 Okt, 19.02',
          leading: AppAvatar(name: 'Pak Dedi'),
          trailing: StatusChip(
            ChipStatus.pendingReview,
            label: 'Menunggu',
          ),
        ),
      ],
    );
  }
}

/// Payment Row (§9.3), Upload tile (8.21) and Image viewer (8.22).
class const _PaymentsSection() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Payments'),
        PaymentRow(
          slotNo: 3,
          name: 'Kamu',
          status: ChipStatus.unpaid,
          subtitle: 'Jatuh tempo Sab, 25 Okt',
          mine: true,
          onUpload: () {},
        ),
        const SizedBox(height: AppSpace.s2),
        PaymentRow(
          slotNo: 7,
          name: 'Pak Dedi',
          status: ChipStatus.pendingReview,
          subtitle: 'Upload 24 Okt, 19.02',
          onReview: () {},
        ),
        const SizedBox(height: AppSpace.s2),
        PaymentRow(
          slotNo: 8,
          name: 'Bu Sri',
          status: ChipStatus.overdue,
          subtitle: 'Jatuh tempo Sab, 18 Okt',
          subtitleAlert: true,
          guest: true,
          menuItems: [
            OverflowMenuItem(label: 'Tandai sudah bayar', icon: AppIcons.handCoins, onSelected: () {}),
          ],
        ),
        const SizedBox(height: AppSpace.s2),
        const PaymentRow(
          slotNo: 9,
          name: 'Mas Andi',
          status: ChipStatus.paid,
          subtitle: 'Dibayar Kemarin · Tunai',
          pendingSync: true,
        ),
        _gap,
        UploadTile(onPick: (_) {}),
        _gap,
        UploadTile(
          errorText: 'Ukuran maksimal 5 MB',
          onPick: (_) {},
          onRetry: () {},
        ),
        _gap,
        AppButton(
          label: 'Image viewer',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => ImageViewer(
                pages: const [
                  ImageViewerPage(url: 'https://picsum.photos/seed/giliran1/900/1600', uploaderName: 'Pak Dedi'),
                  ImageViewerPage(url: 'https://picsum.photos/seed/giliran2/900/1600', uploaderName: 'Pak Dedi'),
                ],
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class const _DoodlesSection() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Doodles'),
        Wrap(
          spacing: AppSpace.s4,
          runSpacing: AppSpace.s4,
          children: [
            for (final d in const [
              AppDoodles.kaleng,
              AppDoodles.slip,
              AppDoodles.tikar,
              AppDoodles.rantang,
              AppDoodles.gelas,
              AppDoodles.kalender,
              AppDoodles.hands,
              AppDoodles.phone,
              AppDoodles.crown,
              AppDoodles.kipas,
            ])
              Doodle(d, size: 72),
          ],
        ),
      ],
    );
  }
}

class const _OnboardingSection() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Illustrations & onboarding'),
        Wrap(
          spacing: AppSpace.s4,
          runSpacing: AppSpace.s4,
          children: [
            for (final asset in const [
              AppIllustrations.splashKaleng,
              AppIllustrations.emailSlip,
              AppIllustrations.emailWaiting,
              AppIllustrations.biometricUnlock,
            ])
              Illustration(asset, width: 72, height: 72),
            for (final (i, page) in WelcomePage.pages.indexed)
              SizedBox(
                width: 150,
                child: OnboardingPanel(
                  illustration: page.illustration,
                  toneIndex: i,
                  height: 130,
                ),
              ),
          ],
        ),
        _gap,
        Wrap(
          spacing: AppSpace.s6,
          children: [
            for (var i = 0; i < 3; i++) PageDots(count: 3, index: i),
          ],
        ),
        _gap,
        AppButton(
          label: 'Lanjut',
          trailingIcon: AppIcons.arrowRight,
          block: true,
          onPressed: () {},
        ),
      ],
    );
  }
}

class const _CardsSection() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = AppTextStyles.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Cards, empty & loading'),
        AppCard(
          style: AppCardStyle.outlined,
          child: Text(
            'Card · outlined',
            style: t.title.copyWith(color: c.textPrimary),
          ),
        ),
        _gap,
        AppCard(
          style: AppCardStyle.dashed,
          child: Text(
            'Buat grup',
            style: t.title.copyWith(color: c.textPrimary),
          ),
        ),
        const EmptyState(
          illustration: Doodle(AppDoodles.rantang, size: 200),
          title: 'Belum ada arisan',
          message: 'Buat grup atau gabung lewat link dari teman.',
          primaryLabel: 'Buat grup',
          secondaryLabel: 'Gabung pakai link',
          onPrimary: null,
        ),
        Row(
          children: [
            const Skeleton.circle(size: 40),
            const SizedBox(width: AppSpace.s3),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton.line(width: 160),
                  SizedBox(height: AppSpace.s2),
                  Skeleton.line(width: 100, height: 12),
                ],
              ),
            ),
            const SkeletonRing(size: 48),
          ],
        ),
        _gap,
        const Skeleton(height: 72, radius: AppRadius.lg),
      ],
    );
  }
}

class const _ChipsSection() extends StatefulWidget {
  @override
  State<_ChipsSection> createState() => _ChipsSectionState();
}

class _ChipsSectionState() extends State<_ChipsSection> {
  int _chip = 0;
  int _tab = 0;
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Chips & tabs'),
        PillTabs(
          tabs: const [
            PillTab('Pembayaran', count: 2),
            PillTab('Jadwal'),
            PillTab('Anggota'),
            PillTab('Aktivitas'),
          ],
          selectedIndex: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        _gap,
        Wrap(
          spacing: AppSpace.s2,
          children: [
            for (final (i, l) in const [
              'Semua',
              'Saya pengurus',
              'Belum bayar',
            ].indexed)
              AppChip(
                label: l,
                selected: i == _chip,
                onSelected: () => setState(() => _chip = i),
              ),
          ],
        ),
        _gap,
        SegmentedPills(
          segments: const ['Periode', 'Bulan'],
          selectedIndex: _segment,
          onChanged: (i) => setState(() => _segment = i),
        ),
      ],
    );
  }
}

class const _InputsSection() extends StatefulWidget {
  @override
  State<_InputsSection> createState() => _InputsSectionState();
}

class _InputsSectionState() extends State<_InputsSection> {
  final _now = DateTime.now();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  final _search = TextEditingController();
  int _slots = 10;
  bool _consent = false;
  String _drawMethod = 'random';
  DateTime? _date;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _amount.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Inputs'),
        const AppTextField(
          label: 'Nama grup',
          hint: 'Arisan RT 05',
          helper: '3–60 karakter',
        ),
        _gap,
        EmailField(controller: _email),
        _gap,
        PhoneField(
          controller: _phone,
          helper: 'Supaya pengurus bisa mengingatkan lewat WhatsApp.',
        ),
        _gap,
        AmountField(
          controller: _amount,
          label: 'Iuran per orang',
          helper: 'Minimal Rp10.000',
        ),
        _gap,
        const AppTextField(
          label: 'Nomor rekening',
          errorText: 'Nomor rekening wajib diisi',
        ),
        _gap,
        SearchField(controller: _search, hint: 'Cari arisan'),
        _gap,
        AppDateField(
          label: 'Tanggal mulai',
          value: _date,
          firstDate: _now,
          lastDate: _now.add(const Duration(days: 365)),
          helper: 'Jatuh tempo pertama. Kocokan sehari setelahnya.',
          onChanged: (d) => setState(() => _date = d),
        ),
        _gap,
        AppStepper(
          label: 'Jumlah slot',
          value: _slots,
          min: 2,
          max: 50,
          unit: 'slot',
          helper: '$_slots periode',
          onChanged: (v) => setState(() => _slots = v),
        ),
        _gap,
        ChoiceCardGroup<String>(
          value: _drawMethod,
          onChanged: (v) => setState(() => _drawMethod = v),
          options: const [
            ChoiceOption(
              value: 'random',
              icon: AppIcons.shuffle,
              title: 'Kocok acak',
              description: 'Pemenang diundi tiap periode. Hasilnya bisa dicek semua anggota.',
            ),
            ChoiceOption(
              value: 'fixed',
              icon: AppIcons.listNumbers,
              title: 'Urutan tetap',
              description: 'Urutan pemenang ditentukan dari awal.',
            ),
          ],
        ),
        _gap,
        CheckRow(
          label: 'Saya sudah transfer Rp200.000 ke rekening pengurus',
          value: _consent,
          onChanged: (v) => setState(() => _consent = v),
        ),
      ],
    );
  }
}

class const _CodeSection() extends StatefulWidget {
  @override
  State<_CodeSection> createState() => _CodeSectionState();
}

class _CodeSectionState() extends State<_CodeSection> {
  // Set once so rebuilds don't restart the countdown.
  final _resendAt = DateTime.now().add(const Duration(seconds: 42));
  final _pin = PinPadController();
  bool _otpError = false;
  bool _pinChecking = false;

  /// Shows the pad's checking state for a moment, then empties it.
  Future<void> _checkPin(String _) async {
    setState(() => _pinChecking = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    _pin.clear();
    setState(() => _pinChecking = false);
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Kode & PIN'),
        Center(
          child: OtpInput(
            error: _otpError,
            onChanged: (_) {
              if (_otpError) setState(() => _otpError = false);
            },
            autofocus: false,
            onCompleted: (code) => setState(() => _otpError = code != '482913'),
          ),
        ),
        _gap,
        Center(
          child: CountdownText(
            prefix: 'Kirim ulang dalam ',
            until: _resendAt,
            showTimeOnSameDay: false,
          ),
        ),
        _gap,
        Center(
          child: PinPad(
            controller: _pin,
            checking: _pinChecking,
            onBiometric: () {},
            onCompleted: _checkPin,
          ),
        ),
      ],
    );
  }
}

/// The email code card (8.35); tap a state chip to preview it.
class const _EmailCodeSection() extends StatefulWidget {
  @override
  State<_EmailCodeSection> createState() => _EmailCodeSectionState();
}

class _EmailCodeSectionState() extends State<_EmailCodeSection> {
  final _resendAt = DateTime.now().add(const Duration(seconds: 42));
  var _state = EmailCodeCardState.waiting;

  String? get _message => switch (_state) {
    EmailCodeCardState.wrong => 'Kode salah. Sisa 2 kali coba.',
    EmailCodeCardState.success => 'Kode benar',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Kode email'),
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          children: [
            for (final state in EmailCodeCardState.values)
              AppChip(
                label: state.name,
                selected: state == _state,
                onSelected: () => setState(() => _state = state),
              ),
          ],
        ),
        _gap,
        EmailCodeCard(
          emailMasked: 'ri•••••@gmail.com',
          state: _state,
          message: _message,
          resendAvailableAt: _resendAt,
          onChangeEmail: () => showAppToast(context, 'Ubah email'),
          onResend: () => showAppToast(context, 'Kirim ulang'),
          onRequestNew: () => setState(() => _state = EmailCodeCardState.waiting),
          onRestart: () => setState(() => _state = EmailCodeCardState.waiting),
          onOpenMail: () => showAppToast(context, 'Buka aplikasi email'),
          onCompleted: (code) => setState(
            () => _state = code == '482913' ? EmailCodeCardState.success : EmailCodeCardState.wrong,
          ),
        ),
      ],
    );
  }
}

class const _ListsSection() extends StatefulWidget {
  @override
  State<_ListsSection> createState() => _ListsSectionState();
}

class _ListsSectionState() extends State<_ListsSection> {
  bool _toggle = true;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Lists & sheets'),
        const KeyValueList(
          items: [
            KeyValueItem('Seharusnya', 'Rp200.000'),
            KeyValueItem('Diupload', '24 Okt, 19.02'),
            KeyValueItem(
              'Kode komitmen',
              '9f2c41d0a7b3e8c5f61d2a9b0c7e4f13a71e',
              mono: true,
              long: true,
              copyable: true,
            ),
          ],
        ),
        _gap,
        SettingsGroup(
          header: 'Akun',
          children: [
            SettingsRow.navigation(
              label: 'Keamanan',
              icon: AppIcons.shieldCheck,
              onTap: () {},
            ),
            SettingsRow.toggle(
              label: 'Pengingat iuran',
              icon: AppIcons.bellRinging,
              toggleValue: _toggle,
              onToggle: (v) => setState(() => _toggle = v),
            ),
            const SettingsRow.info(
              label: 'Versi app',
              icon: AppIcons.info,
              value: '0.1.0',
            ),
            const SettingsRow.locked(
              label: 'Iuran',
              icon: AppIcons.money,
              value: 'Rp200.000',
            ),
            SettingsRow.destructive(
              label: 'Keluar',
              icon: AppIcons.signOut,
              onTap: () => showAppDialog(
                context,
                title: 'Keluar dari Giliran?',
                confirmLabel: 'Keluar',
              ),
            ),
          ],
        ),
        const ActivityRow(
          icon: AppIcons.pencilSimple,
          title: 'Bu Rina mengubah iuran',
          time: '19.30',
          diffs: [ActivityRowDiff(label: 'iuran', before: 'Rp150.000', after: 'Rp200.000')],
        ),
        const ActivityRow(icon: AppIcons.flag, title: 'Arisan dimulai', time: '08.00', system: true),
        _gap,
        NotificationItem(
          id: 'g-unread',
          icon: AppIcons.bellRinging,
          title: 'Iuran jatuh tempo besok',
          body: 'Rp200.000 untuk periode 4',
          time: '19.30',
          groupName: 'Arisan RT 05',
          toneColor: c.tones[0].accent,
          read: false,
          onTap: () => showAppToast(context, 'Buka'),
          onMarkRead: () => showAppToast(context, 'Dibaca'),
        ),
        NotificationItem(
          id: 'g-read',
          icon: AppIcons.shuffle,
          title: 'Hasil kocokan periode 4',
          time: '08.00',
          groupName: 'Arisan RT 05',
          toneColor: c.tones[0].accent,
          read: true,
          onTap: () => showAppToast(context, 'Buka'),
          onMarkRead: () {},
        ),
        _gap,
        SettingsGroup(
          header: 'Perangkat aktif',
          children: [
            const SessionRow(deviceName: 'Pixel 8', platform: 'android', current: true),
            SessionRow(
              deviceName: 'iPhone 15',
              platform: 'ios',
              lastActiveAt: DateTime.utc(2026, 11, 3, 8),
              now: DateTime.utc(2026, 11, 3, 10),
              onSignOut: () {},
            ),
          ],
        ),
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          children: [
            AppButton.secondary(
              label: 'Konfirmasi',
              size: AppButtonSize.small,
              onPressed: () => showConfirmationSheet(
                context,
                icon: AppIcons.checkCircle,
                toneColor: c.paid.bg,
                title: 'Setujui bayaran Pak Dedi?',
                summary: const [
                  KeyValueItem('Anggota', 'Pak Dedi · slot 07'),
                  KeyValueItem('Jumlah', 'Rp200.000'),
                  KeyValueItem('Periode', '4'),
                ],
                consentLabel: 'Uang sudah masuk ke rekening saya',
                confirmLabel: 'Setujui',
              ),
            ),
            AppButton.secondary(
              label: 'Bantuan',
              size: AppButtonSize.small,
              onPressed: () => showHelpSheet(
                context,
                title: 'Cara kerja kocokan',
                paragraphs: const [
                  '1. Kode dikunci: sebelum kocokan, aplikasi membuat kode komitmen dan menunjukkannya ke semua anggota.',
                  '2. Kocok: pengurus menekan Kocok, pemenang dipilih dari kunci rahasia.',
                  '3. Semua bisa cek: kunci rahasia dibuka, siapa pun bisa menghitung ulang hasilnya.',
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class const _ScreensSection() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Screens'),
        SettingsGroup(
          children: [
            SettingsRow.navigation(
              label: 'Ubah PIN (S45)',
              icon: AppIcons.lockSimple,
              onTap: () => const ChangePinRoute().push<void>(context),
            ),
            SettingsRow.navigation(
              label: 'Ubah email (S46)',
              icon: AppIcons.envelopeSimple,
              onTap: () => const ChangeEmailRoute().push<void>(context),
            ),
          ],
        ),
      ],
    );
  }
}
