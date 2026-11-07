import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feedback_widgets.dart';
import 'auth_widgets.dart';
import 'session_provider.dart';

/// S-02 Registro. Siempre crea un Cliente; la sesion queda iniciada (PA-UX-04).
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  String? _banner;
  String? _nameError;
  String? _emailError;
  bool _emailTaken = false;
  String? _passwordError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _banner = null;
      _nameError = _emailError = _passwordError = null;
      _emailTaken = false;
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final user = await ref
          .read(sessionProvider.notifier)
          .register(_name.text.trim(), _email.text.trim(), _password.text);
      messenger.showSnackBar(SnackBar(content: Text('¡Bienvenido, ${user.fullName}!')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        switch (e.code) {
          case ErrorCodes.emailExists:
            _emailTaken = true;
            _emailError = 'Este email ya está registrado.';
          case ErrorCodes.validation:
            final fields = e.fieldErrors;
            _nameError = fields['fullName'];
            _emailError = fields['email'];
            _passwordError = fields['password'];
            if (fields.isEmpty) _banner = e.userMessage;
          default:
            _banner = e.userMessage;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthCard(
      title: 'Crear cuenta',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                enabled: !_busy,
                autofocus: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(labelText: 'Nombre completo', errorText: _nameError),
                validator: (v) {
                  final n = (v ?? '').trim();
                  return n.length >= 2 && n.length <= 120
                      ? null
                      : 'Ingresa tu nombre completo (mínimo 2 caracteres).';
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: 'Email', errorText: _emailError),
                validator: (v) {
                  final e = (v ?? '').trim();
                  return emailPattern.hasMatch(e) && e.length <= 254 ? null : 'Ingresa un email válido.';
                },
              ),
              if (_emailTaken)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Iniciar sesión'),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                controller: _password,
                label: 'Contraseña',
                helperText: 'Mínimo 8 caracteres',
                enabled: !_busy,
                errorText: _passwordError,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final p = v ?? '';
                  return p.length >= 8 && p.length <= 72
                      ? null
                      : 'La contraseña debe tener al menos 8 caracteres.';
                },
              ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                controller: _repeat,
                label: 'Repetir contraseña',
                enabled: !_busy,
                validator: (v) => v == _password.text ? null : 'Las contraseñas no coinciden.',
                onSubmitted: (_) => _submit(),
              ),
              if (_banner != null) ...[
                const SizedBox(height: AppSpacing.md),
                ErrorBanner(message: _banner!),
              ],
              const SizedBox(height: AppSpacing.md),
              BusyButton(label: 'Crear cuenta', busyLabel: 'Creando cuenta…', busy: _busy, onPressed: _submit),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('¿Ya tienes cuenta?'),
                  TextButton(
                    onPressed: _busy ? null : () => context.go('/login'),
                    child: const Text('Iniciar sesión'),
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
