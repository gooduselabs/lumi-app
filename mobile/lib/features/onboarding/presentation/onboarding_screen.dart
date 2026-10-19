import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../profile/data/profile_repository.dart';

const kMaxInterests = 8;

int ageFrom(DateTime b, [DateTime? now]) {
  final n = now ?? DateTime.now();
  var a = n.year - b.year;
  if (n.month < b.month || (n.month == b.month && n.day < b.day)) a--;
  return a;
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  final _nickname = TextEditingController();
  final _bio = TextEditingController();
  int _step = 0;
  String? _gender;
  DateTime? _birthday;
  String _avatar = 'a07';
  final Set<String> _interests = {};
  bool _saving = false;

  static const _total = 4;

  @override
  void dispose() {
    _pages.dispose();
    _nickname.dispose();
    _bio.dispose();
    super.dispose();
  }

  bool get _canNext => switch (_step) {
        0 => _nickname.text.trim().length >= 2 && _gender != null,
        1 => _birthday != null && ageFrom(_birthday!) >= 18,
        2 => true,
        _ => _interests.isNotEmpty,
      };

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _pages.animateToPage(step, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final me = await ref.read(profileRepositoryProvider).onboard(
            nickname: _nickname.text.trim(),
            gender: _gender!,
            birthday: _birthday!,
            avatarId: _avatar,
            bio: _bio.text.trim(),
            interests: _interests.toList(),
          );
      ref.read(authControllerProvider.notifier).updateMe(me);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, context.l10n.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(colorScheme: Theme.of(c).colorScheme.copyWith(primary: AppColors.violet)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: GlowBackground(
        intensity: 0.6,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                AnimatedOpacity(
                  opacity: _step > 0 ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IconButton(onPressed: _step > 0 ? () => _go(_step - 1) : null, icon: const Icon(Icons.arrow_back_rounded)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: (_step + 1) / _total),
                      duration: const Duration(milliseconds: 380),
                      builder: (_, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 6,
                        backgroundColor: AppColors.surface,
                        valueColor: const AlwaysStoppedAnimation(AppColors.pink),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(l.onbStep(_step + 1, _total), style: const TextStyle(color: AppColors.textMuted)),
                const SizedBox(width: 8),
              ]),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [_nameStep(), _birthdayStep(), _avatarStep(), _interestsStep()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: GradientButton(
                label: _step == _total - 1 ? l.finish : l.next,
                loading: _saving,
                onPressed: _canNext ? () => _step == _total - 1 ? _finish() : _go(_step + 1) : null,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _stepShell({required String title, required String subtitle, required Widget child}) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
          const SizedBox(height: 28),
          child,
        ]),
      );

  Widget _nameStep() {
    final l = context.l10n;
    Widget g(String v, String label, IconData icon) {
      final sel = _gender == v;
      return Expanded(
        child: GlassCard(
          gradient: sel ? AppColors.primaryGradient : null,
          onTap: () => setState(() => _gender = v),
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(children: [Icon(icon, size: 28), const SizedBox(height: 6), Text(label, style: const TextStyle(fontWeight: FontWeight.w700))]),
        ),
      );
    }

    return _stepShell(
      title: l.onbNameTitle,
      subtitle: l.onbNameSubtitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _nickname,
          maxLength: 24,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: l.nickname, prefixIcon: const Icon(Icons.badge_outlined)),
        ),
        const SizedBox(height: 12),
        Text(l.gender, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: [
          g('MALE', l.genderMale, Icons.male_rounded),
          const SizedBox(width: 12),
          g('FEMALE', l.genderFemale, Icons.female_rounded),
          const SizedBox(width: 12),
          g('OTHER', l.genderOther, Icons.auto_awesome_rounded),
        ]),
      ]),
    );
  }

  Widget _birthdayStep() {
    final l = context.l10n;
    final age = _birthday != null ? ageFrom(_birthday!) : null;
    final under = age != null && age < 18;
    return _stepShell(
      title: l.onbBirthdayTitle,
      subtitle: l.onbBirthdaySubtitle,
      child: Column(children: [
        GlassCard(
          onTap: _pickBirthday,
          child: Row(children: [
            const Icon(Icons.cake_outlined, color: AppColors.pink),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _birthday == null ? l.pickBirthday : DateFormat('dd/MM/yyyy').format(_birthday!),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            if (age != null)
              Text(l.ageYears(age), style: TextStyle(color: under ? AppColors.danger : AppColors.mint, fontWeight: FontWeight.w700)),
          ]),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: under
              ? Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Row(children: [
                    const Icon(Icons.block_rounded, color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l.underageError, style: const TextStyle(color: AppColors.danger))),
                  ]),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  Widget _avatarStep() {
    final l = context.l10n;
    return _stepShell(
      title: l.onbAvatarTitle,
      subtitle: l.onbAvatarSubtitle,
      child: Column(children: [
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: LumiAvatar(key: ValueKey(_avatar), avatarId: _avatar, size: 120, ring: true),
          ),
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (final id in LumiAvatar.ids)
              GestureDetector(
                onTap: () => setState(() => _avatar = id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _avatar == id ? AppColors.primaryGradient : null,
                  ),
                  child: LumiAvatar(avatarId: id, size: 44),
                ),
              ),
          ],
        ),
      ]),
    );
  }

  Widget _interestsStep() {
    final l = context.l10n;
    return _stepShell(
      title: l.onbInterestsTitle,
      subtitle: l.onbInterestsSubtitle(kMaxInterests),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 10, children: [
          for (final k in kInterestKeys)
            InterestChip(
              keyName: k,
              selected: _interests.contains(k),
              onTap: () => setState(() {
                if (_interests.contains(k)) {
                  _interests.remove(k);
                } else if (_interests.length < kMaxInterests) {
                  _interests.add(k);
                }
              }),
            ),
        ]),
        const SizedBox(height: 24),
        TextField(
          controller: _bio,
          maxLength: 160,
          maxLines: 3,
          minLines: 2,
          decoration: InputDecoration(labelText: l.bio, hintText: l.bioHint, alignLabelWithHint: true),
        ),
      ]),
    );
  }
}
