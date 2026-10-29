import 'package:material_ui/material_ui.dart';

import '../core/constants/app_doodles.dart';
import '../core/constants/app_icons.dart';
import '../core/constants/app_illustrations.dart';
import '../core/themes/themes.dart';
import '../features/auth/presentation/pages/welcome_page.dart';
import '../shared/widgets/widgets.dart';

/// Debug gallery of the Tikar components in light and dark, used to compare
/// against the design system previews. Remove once real screens exist.
class ComponentGalleryPage extends StatefulWidget {
  const ComponentGalleryPage({super.key});

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  bool? _dark;

  @override
  Widget build(BuildContext context) {
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
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

class _Gallery extends StatefulWidget {
  const _Gallery({required this.dark, required this.onToggleTheme});

  final bool dark;
  final VoidCallback onToggleTheme;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  static const _sections = [
    _HeroSection(),
    _ButtonsSection(),
    _StatusSection(),
    _ChipsSection(),
    _InputsSection(),
    _CodeSection(),
    _PeopleSection(),
    _ListsSection(),
    _DoodlesSection(),
    _OnboardingSection(),
    _CardsSection(),
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
            context.isCompact
                ? AppBottomNavBar.contentInset(context)
                : AppSpace.s8,
          ),
          itemCount: _sections.length,
          itemBuilder: (context, i) => MaxWidth(child: _sections[i]),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

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

class _ButtonsSection extends StatelessWidget {
  const _ButtonsSection();

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

class _StatusSection extends StatelessWidget {
  const _StatusSection();

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
        const AppBanner(
          variant: AppBannerVariant.offline,
          message: 'Offline. Data terakhir 19.02.',
        ),
        _gap,
        AppBanner(
          variant: AppBannerVariant.success,
          message: 'Semua sudah bayar periode ini.',
          onDismiss: () {},
        ),
      ],
    );
  }
}

class _PeopleSection extends StatelessWidget {
  const _PeopleSection();

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

class _DoodlesSection extends StatelessWidget {
  const _DoodlesSection();

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

class _OnboardingSection extends StatelessWidget {
  const _OnboardingSection();

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
            const Illustration(
              AppIllustrations.splashKaleng,
              width: 72,
              height: 72,
            ),
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

class _CardsSection extends StatelessWidget {
  const _CardsSection();

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

class _ChipsSection extends StatefulWidget {
  const _ChipsSection();

  @override
  State<_ChipsSection> createState() => _ChipsSectionState();
}

class _ChipsSectionState extends State<_ChipsSection> {
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

class _InputsSection extends StatefulWidget {
  const _InputsSection();

  @override
  State<_InputsSection> createState() => _InputsSectionState();
}

class _InputsSectionState extends State<_InputsSection> {
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

class _CodeSection extends StatefulWidget {
  const _CodeSection();

  @override
  State<_CodeSection> createState() => _CodeSectionState();
}

class _CodeSectionState extends State<_CodeSection> {
  // Set once so rebuilds don't restart the countdown.
  final _resendAt = DateTime.now().add(const Duration(seconds: 42));
  final _pin = PinPadController();
  bool _otpError = false;

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
          ),
        ),
        _gap,
        Center(
          child: PinPad(
            controller: _pin,
            onBiometric: () {},
            onCompleted: (_) => _pin.clear(),
          ),
        ),
      ],
    );
  }
}

class _ListsSection extends StatefulWidget {
  const _ListsSection();

  @override
  State<_ListsSection> createState() => _ListsSectionState();
}

class _ListsSectionState extends State<_ListsSection> {
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
