import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/feedback_widgets.dart';
import 'auth_widgets.dart';
import 'session_provider.dart';

/// S-01 Iniciar sesion.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !ref.read(sessionExpiredNoticeProvider)) return;
      ref.read(sessionExpiredNoticeProvider.notifier).clear();
      await showSessionExpiredDialog(context);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).login(_email.text.trim(), _password.text);
      // La redireccion por rol la hace el router al cambiar la sesion.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (e.code) {
          ErrorCodes.invalidCredentials => 'Email o contraseña incorrectos.',
          ErrorCodes.forbidden => 'Tu cuenta está desactivada. Consulta con el local.',
          ErrorCodes.rateLimited => 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.',
          _ => e.userMessage,
        };
      });
      if (e.code == ErrorCodes.invalidCredentials) {
        _password.clear();
        _passwordFocus.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthCard(
      title: 'Iniciar sesión',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                enabled: !_busy,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => emailPattern.hasMatch((v ?? '').trim()) ? null : 'Ingresa un email válido.',
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                controller: _password,
                focusNode: _passwordFocus,
                label: 'Contraseña',
                enabled: !_busy,
                validator: (v) => (v ?? '').isEmpty ? 'Ingresa tu contraseña.' : null,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                ErrorBanner(message: _error!),
              ],
              const SizedBox(height: AppSpacing.md),
              BusyButton(label: 'Iniciar sesión', busyLabel: 'Ingresando…', busy: _busy, onPressed: _submit),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('¿No tienes cuenta?'),
                  TextButton(
                    onPressed: _busy ? null : () => context.go('/register'),
                    child: const Text('Crear cuenta'),
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
