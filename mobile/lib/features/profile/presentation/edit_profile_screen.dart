import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../onboarding/presentation/onboarding_screen.dart' show kMaxInterests;
import '../data/profile_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final _me = ref.read(meProvider)!;
  late final _nickname = TextEditingController(text: _me.nickname);
  late final _bio = TextEditingController(text: _me.bio);
  late String _avatar = _me.avatarId ?? 'a01';
  late final Set<String> _interests = {..._me.interests};
  bool _saving = false;

  @override
  void dispose() {
    _nickname.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (_nickname.text.trim().length < 2) return;
    setState(() => _saving = true);
    try {
      final me = await ref.read(profileRepositoryProvider).update({
        'nickname': _nickname.text.trim(),
        'bio': _bio.text.trim(),
        'avatarId': _avatar,
        'interests': _interests.toList(),
      });
      ref.read(authControllerProvider.notifier).updateMe(me);
      if (!mounted) return;
      showSnack(context, l.saved);
      context.pop();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, l.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.editProfile)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Center(child: LumiAvatar(avatarId: _avatar, size: 100, ring: true)),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final id in LumiAvatar.ids)
              GestureDetector(
                onTap: () => setState(() => _avatar = id),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: _avatar == id ? AppColors.primaryGradient : null),
                  child: LumiAvatar(avatarId: id, size: 46),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 20),
        TextField(controller: _nickname, maxLength: 24, decoration: InputDecoration(labelText: l.nickname)),
        const SizedBox(height: 8),
        TextField(controller: _bio, maxLength: 160, maxLines: 3, decoration: InputDecoration(labelText: l.bio, hintText: l.bioHint)),
        const SizedBox(height: 12),
        Text(l.interests, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 10, children: [
          for (final k in kInterestKeys)
            InterestChip(
              keyName: k,
              selected: _interests.contains(k),
              onTap: () => setState(() {
                if (!_interests.remove(k) && _interests.length < kMaxInterests) _interests.add(k);
              }),
            ),
        ]),
        const SizedBox(height: 28),
        GradientButton(label: l.save, loading: _saving, onPressed: _save),
      ]),
    );
  }
}
