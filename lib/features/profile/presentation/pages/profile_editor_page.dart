import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/private_image.dart';
import '../../data/profile_repository.dart';
import '../../data/image_upload_service.dart';
import '../../data/models/profile.dart';
import '../../../../app/router/auth_redirect.dart';

class ProfileEditorPage extends ConsumerStatefulWidget {
  final bool onboarding;
  const ProfileEditorPage({super.key, this.onboarding = false});
  @override
  ConsumerState<ProfileEditorPage> createState() => _ProfileEditorPageState();
}

class _ProfileEditorPageState extends ConsumerState<ProfileEditorPage> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController(),
      _last = TextEditingController(),
      _username = TextEditingController(),
      _display = TextEditingController();
  bool _loaded = false, _busy = false, _hidden = false;
  String? _photo, _originalPhoto;
  void _populate(Profile? profile) {
    if (_loaded) return;
    _loaded = true;
    _first.text = profile?.firstName ?? '';
    _last.text = profile?.lastName ?? '';
    _username.text = profile?.username ?? '';
    _display.text = profile?.displayName ?? '';
    _photo = _originalPhoto = profile?.avatarPath;
    _hidden = profile?.hideActivity ?? false;
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _username, _display]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await runAction(context, () async {
      await ref
          .read(profileRepositoryProvider)
          .save(
            username: _username.text,
            displayName: _display.text,
            firstName: _first.text,
            lastName: _last.text,
            avatarPath: _photo,
            hideActivity: _hidden,
          );
      if (_originalPhoto != null && _originalPhoto != _photo) {
        try {
          await ref.read(imageUploadProvider).removeAvatar(_originalPhoto!);
        } catch (_) {
          /* A later cleanup can remove an unreferenced object. */
        }
      }
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        final next = returnLocation(
          GoRouterState.of(context).uri.queryParameters['next'],
        );
        context.go(
          widget.onboarding
              ? '/permissions?next=${Uri.encodeComponent(next)}'
              : '/profile',
        );
      }
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.onboarding ? 'Make yourself at home' : 'Edit profile',
        ),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            ErrorView(onRetry: () => ref.invalidate(currentProfileProvider)),
        data: (value) {
          _populate(value);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: ProfileAvatar(
                        name: _display.text,
                        path: _photo,
                        size: 96,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              await runAction(context, () async {
                                final path = await ref
                                    .read(imageUploadProvider)
                                    .selectAndUpload('avatars');
                                if (path != null && mounted) {
                                  setState(() => _photo = path);
                                }
                              });
                              if (mounted) setState(() => _busy = false);
                            },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Choose a photo'),
                    ),
                    if (_photo != null)
                      TextButton(
                        onPressed: () => setState(() => _photo = null),
                        child: const Text('Remove photo'),
                      ),
                    const SizedBox(height: 16),
                    for (final field in [
                      (_first, 'First name'),
                      (_last, 'Last name'),
                      (_display, 'Display name'),
                      (_username, 'Username'),
                    ]) ...[
                      TextFormField(
                        controller: field.$1,
                        maxLength: field.$2 == 'Username' ? 24 : 80,
                        decoration: InputDecoration(
                          labelText: field.$2,
                          helperText: field.$2 == 'Username'
                              ? '3–24 letters, numbers, or underscores'
                              : null,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Please enter your ${field.$2.toLowerCase()}'
                            : field.$2 == 'Username' &&
                                  !RegExp(r'^[a-zA-Z0-9_]{3,24}$').hasMatch(v)
                            ? 'Use 3–24 letters, numbers, or underscores'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(
                        _busy
                            ? 'Saving…'
                            : widget.onboarding
                            ? 'Continue'
                            : 'Save profile',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
