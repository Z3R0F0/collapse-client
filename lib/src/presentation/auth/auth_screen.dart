import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/config.dart';
import '../../../core/theme.dart';
import '../../data/auth/auth_repository.dart';
import 'auth_cubit.dart';

part 'auth_fields.dart';
part 'auth_form.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.config});
  final AppConfig config;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  void _toggleMode() => setState(() => _register = !_register);
  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    context.read<AuthCubit>().signIn(
      _username.text,
      _password.text,
      displayName: _register ? _name.text : null,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: BlocBuilder<AuthCubit, SessionState>(
              builder: (context, state) => _buildForm(context, state),
            ),
          ),
        ),
      ),
    ),
  );
}
