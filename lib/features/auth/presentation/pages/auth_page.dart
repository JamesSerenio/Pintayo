import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/brand.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../application/auth_controller.dart';
import '../../../../app/router/auth_redirect.dart';

class AuthPage extends ConsumerStatefulWidget {
  final bool recovery;
  const AuthPage({super.key, this.recovery = false});
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  bool _register = false, _busy = false, _obscure = true;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await runAction(context, () async {
      final controller = ref.read(authControllerProvider);
      if (widget.recovery) {
        await controller.recover(_password.text);
      } else if (_register) {
        await controller.register(_email.text, _password.text);
        if (mounted) {
          showNotice(
            context,
            'Check your email to confirm your account, then sign in.',
          );
        }
      } else {
        await controller.login(_email.text, _password.text);
      }
      if (mounted) {
        final next = GoRouterState.of(context).uri.queryParameters['next'];
        final recipient = GoRouterState.of(
          context,
        ).uri.queryParameters['notificationRecipient'];
        if (recipient != null && recipient != controller.userId) {
          context.go('/map');
          showNotice(context, 'This notification belongs to another account.');
        } else {
          context.go(returnLocation(next));
        }
      }
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(28),
            children: [
              const Brand(),
              const SizedBox(height: 48),
              Text(
                widget.recovery
                    ? 'A fresh start'
                    : _register
                    ? 'Find your people.'
                    : 'Welcome back.',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.recovery
                    ? 'Choose your new password.'
                    : 'Your people. Your places. Your choice.',
              ),
              const SizedBox(height: 28),
              Form(
                key: _form,
                child: Column(
                  children: [
                    if (!widget.recovery) ...[
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        validator: (v) => v != null && v.contains('@')
                            ? null
                            : 'Enter your email address',
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: [
                        widget.recovery || _register
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: 'Show password',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) => (v?.length ?? 0) >= 8
                          ? null
                          : 'Use at least 8 characters',
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(
                          _busy
                              ? 'Please wait…'
                              : widget.recovery
                              ? 'Update password'
                              : _register
                              ? 'Create account'
                              : 'Sign in',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.recovery) ...[
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => runAction(context, () async {
                          if (!_email.text.contains('@')) {
                            showNotice(context, 'Enter your email first.');
                            return;
                          }
                          await ref
                              .read(authControllerProvider)
                              .reset(_email.text);
                          if (context.mounted) {
                            showNotice(
                              context,
                              'If this address has an account, a reset link is on its way.',
                            );
                          }
                        }),
                  child: const Text('Forgot password?'),
                ),
                const Divider(),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _register = !_register),
                  child: Text(
                    _register
                        ? 'Already together? Sign in'
                        : 'New here? Create an account',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Private by default. Location sharing is always your choice.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
