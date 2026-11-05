import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:girlfriend/core/app_config.dart';
import 'package:girlfriend/core/haptics.dart';
import 'package:girlfriend/data/analytics/analytics_service.dart';
import 'package:girlfriend/data/navigation_service.dart';
import 'package:girlfriend/data/url_launcher_service.dart';
import 'package:girlfriend/presentation/view_model/auth_provider.dart';
import 'package:girlfriend/presentation/view_model/chat_list_provider.dart';
import 'package:girlfriend/presentation/view_model/user_provider.dart';
import 'package:girlfriend/presentation/widget/auth_widgets.dart';
import 'package:girlfriend/presentation/widget/sophia_style.dart';
import 'package:girlfriend/presentation/widget/sophia_toast.dart';
import 'package:provider/provider.dart';
import 'about_you_screen.dart';
import 'login_screen.dart';

/// Create account. Email sign-up goes through the same register-login call as
/// Sign in; the name is saved right after with [UserProvider.updateName].
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final _termsTap = TapGestureRecognizer()
    ..onTap = Haptics.wrap(() => UrlLauncherService.launch(AppConfig.termsOfServiceUrl));
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = Haptics.wrap(() => UrlLauncherService.launch(AppConfig.privacyPolicyUrl));
  bool _obscurePassword = true;
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen(
      screenName: 'RegisterScreen',
      innerScreenName: 'CreateAccount',
      context: 'authentication',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      Haptics.error();
      SophiaToast.show(msg: "Please confirm you're 18+ and accept the Terms.");
      return;
    }
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final chatListProvider = context.read<ChatListProvider>();
    await authProvider.signInWithEmailPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      userProvider: userProvider,
      chatListProvider: chatListProvider,
      onSuccess: (msg) {
        SophiaToast.show(msg: msg);
        if (!mounted) return;
        Navigator.pop(context);
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (name != userProvider.name) await userProvider.updateName(name);
          final ctx = NavigationService.navigatorKey.currentContext;
          if (ctx == null) return;
          if (!userProvider.needsAboutYou) return;
          await AboutYouScreen.open(ctx, isOnboarding: true);
        });
      },
      onError: (msg) {
        SophiaToast.show(msg: msg);
      },
    );
  }

  Future<void> _signUpWithGoogle() async {
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final chatListProvider = context.read<ChatListProvider>();
    await authProvider.signInWithGoogle(
      webClientId: AppConfig.googleWebClientId,
      userProvider: userProvider,
      chatListProvider: chatListProvider,
      onSuccess: (msg) {
        SophiaToast.show(msg: msg);
        if (!mounted) return;
        Navigator.pop(context);
      },
      onError: (msg) {
        SophiaToast.show(msg: msg);
      },
    );
  }

  Future<void> _signUpWithApple() async {
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final chatListProvider = context.read<ChatListProvider>();
    await authProvider.signInWithApple(
      userProvider: userProvider,
      chatListProvider: chatListProvider,
      onSuccess: (msg) {
        SophiaToast.show(msg: msg);
        if (!mounted) return;
        Navigator.pop(context);
      },
      onError: (msg) {
        SophiaToast.show(msg: msg);
      },
    );
  }

  void _openLogin() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  /// 0–4 filled bars.
  int get _strength {
    final p = _passwordController.text;
    if (p.isEmpty) return 0;
    var score = p.length >= 8 ? 1 : 0;
    if (p.length >= 12) score++;
    if (RegExp(r'\d').hasMatch(p)) score++;
    if (RegExp(r'[A-Z]').hasMatch(p) || RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final heroHeight = (MediaQuery.sizeOf(context).height * 0.25).clamp(180.0, 230.0);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final busy = authProvider.isSigningIn;
        return Scaffold(
          backgroundColor: SophiaColors.bgTop,
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: SophiaColors.background),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: CustomScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: AuthHero(
                        image: 'assets/images/onboard3.png',
                        message: "Hi, I'm Sophia. What should I call you?",
                        height: heroHeight,
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, 10, 24, 12 + bottomInset),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const AuthHeading(
                              title: 'Create your account',
                              subtitle: 'Save your chats and use Sophia on any device.',
                            ),
                            const SizedBox(height: 18),
                            AuthField(
                              label: 'Your name',
                              controller: _nameController,
                              icon: Icons.person_outline_rounded,
                              hint: 'What should Sophia call you?',
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.givenName],
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'Please enter your name';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            AuthField(
                              label: 'Email',
                              controller: _emailController,
                              icon: Icons.mail_outline_rounded,
                              hint: 'you@email.com',
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'Email is required';
                                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return 'Enter a valid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            AuthField(
                              label: 'Password',
                              controller: _passwordController,
                              icon: Icons.lock_outline_rounded,
                              hint: 'At least 8 characters',
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              onChanged: (_) => setState(() {}),
                              validator: (value) {
                                final v = value ?? '';
                                if (v.isEmpty) return 'Password is required';
                                if (v.length < 8) return 'Password must be at least 8 characters';
                                return null;
                              },
                              suffix: PasswordEye(
                                obscured: _obscurePassword,
                                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _StrengthBar(strength: _strength),
                            const SizedBox(height: 14),
                            _AgreeRow(
                              agreed: _agreed,
                              onToggle: () => setState(() => _agreed = !_agreed),
                              termsTap: _termsTap,
                              privacyTap: _privacyTap,
                            ),
                            const SizedBox(height: 18),
                            AmethystButton(
                              label: busy ? 'Creating account…' : 'Create account',
                              height: 54,
                              onTap: busy ? null : _createAccount,
                            ),
                            const SizedBox(height: 20),
                            const AuthDivider(text: 'or sign up with'),
                            const SizedBox(height: 14),
                            AuthSocialRow(
                              onGoogle: busy ? null : _signUpWithGoogle,
                              onApple: busy ? null : _signUpWithApple,
                            ),
                            const SizedBox(height: 12),
                            const Spacer(),
                            AuthFooterLink(text: 'Already have an account? ', action: 'Sign in', onTap: _openLogin),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StrengthBar extends StatelessWidget {
  final int strength;

  const _StrengthBar({required this.strength});

  static const _labels = ['', 'Weak', 'Okay', 'Good', 'Strong'];

  @override
  Widget build(BuildContext context) {
    final label = _labels[strength];
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: i >= strength
                    ? Colors.white.withValues(alpha: 0.1)
                    : (i == strength - 1 ? SophiaColors.champagne : SophiaColors.orchid),
              ),
            ),
          ),
        ],
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(color: SophiaColors.champagne, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _AgreeRow extends StatelessWidget {
  final bool agreed;
  final VoidCallback onToggle;
  final GestureRecognizer termsTap;
  final GestureRecognizer privacyTap;

  const _AgreeRow({
    required this.agreed,
    required this.onToggle,
    required this.termsTap,
    required this.privacyTap,
  });

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(color: SophiaColors.lilac, decoration: TextDecoration.underline);
    return Semantics(
      checked: agreed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: Haptics.wrap(onToggle),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: agreed
                    ? const LinearGradient(colors: [SophiaColors.amethystMid, Color(0xFF9877CF)])
                    : null,
                border: agreed ? null : Border.all(color: SophiaColors.lilac.withValues(alpha: 0.4), width: 1.4),
              ),
              child: agreed ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(color: SophiaColors.muted, fontSize: 12.5, height: 1.45),
                  children: [
                    const TextSpan(text: "I'm 18 or older and agree to the "),
                    TextSpan(text: 'Terms', style: link, recognizer: termsTap),
                    const TextSpan(text: ' and '),
                    TextSpan(text: 'Privacy Policy', style: link, recognizer: privacyTap),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
