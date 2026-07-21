import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email aur password daalein')),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
      if (!mounted) return;
      context.go('/dashboard');
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary, cs.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.school_rounded, size: 48, color: cs.primary),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Text('NEMPS',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold, color: cs.primary)),
                        ),
                        Center(
                          child: Text('Teacher Assistant',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'School Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: password,
                          obscureText: obscure,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => obscure = !obscure),
                            ),
                          ),
                          onSubmitted: (_) => busy ? null : _signIn(),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: busy ? null : _signIn,
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52)),
                          icon: busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.login),
                          label: Text(busy ? 'Signing in...' : 'Sign In'),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () => context.go('/signup'),
                            child: const Text('Naya account banayein'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Signup
// ---------------------------------------------------------------------------

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final fullName = TextEditingController();
  final phone = TextEditingController();
  bool busy = false;
  bool agreeTerms = false;
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    fullName.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (email.text.isEmpty || password.text.isEmpty || fullName.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sabhi zaruri fields bharein')),
      );
      return;
    }
    if (password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password kam se kam 6 characters ka hona chahiye')),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: email.text.trim(),
        password: password.text,
        data: {'full_name': fullName.text, 'phone': phone.text},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Account ban gaya! Email verify karein.'),
            backgroundColor: Colors.green),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.go('/login');
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Account Banayein')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NEMPS join karein',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Teacher account banayein',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant)),
                  const SizedBox(height: 28),
                  TextField(
                    controller: fullName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Full Name *', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'School Email *', prefixIcon: Icon(Icons.email_outlined)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: password,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      helperText: 'Kam se kam 6 characters',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Phone Number (optional)',
                        prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: agreeTerms,
                        onChanged: (v) => setState(() => agreeTerms = v ?? false),
                      ),
                      const Expanded(child: Text('Terms & conditions se agree karein')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: (busy || !agreeTerms) ? null : _signUp,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    icon: busy
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.person_add),
                    label: Text(busy ? 'Creating...' : 'Sign Up'),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Pehle se account hai? Sign in karein'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
