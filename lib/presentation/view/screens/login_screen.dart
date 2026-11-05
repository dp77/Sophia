import 'package:girlfriend/presentation/widget/sophia_style.dart';
import 'package:flutter/material.dart';
import 'about_you_screen.dart';
import 'register_screen.dart';
import 'package:girlfriend/presentation/widget/auth_widgets.dart';
import 'package:girlfriend/presentation/widget/sophia_toast.dart';
import 'package:girlfriend/core/app_config.dart';
import 'package:girlfriend/data/analytics/analytics_service.dart';
import 'package:girlfriend/data/navigation_service.dart';
import 'package:girlfriend/presentation/view_model/auth_provider.dart';
import 'package:girlfriend/presentation/view_model/chat_list_provider.dart';
import 'package:girlfriend/presentation/view_model/user_provider.dart';
import 'package:provider/provider.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen(
      screenName: 'LoginScreen',
      innerScreenName: 'SignIn',
      context: 'authentication',
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
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

  Future<void> _signInWithGoogle() async {
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

  Future<void> _signInWithApple() async {
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

  /// Swaps this screen for Create account, so a finished sign-up returns
  /// straight to whichever screen opened Sign in.
  void _openRegister() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final heroHeight = (MediaQuery.sizeOf(context).height * 0.34).clamp(230.0, 320.0);
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
                        image: 'assets/images/onboard1.png',
                        message: "You're back. I kept our chats safe for you.",
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
                              title: 'Welcome back',
                              subtitle: 'Sign in to pick up where you left off.',
                            ),
                            const SizedBox(height: 22),
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
                            const SizedBox(height: 14),
                            AuthField(
                              label: 'Password',
                              controller: _passwordController,
                              icon: Icons.lock_outline_rounded,
                              hint: 'At least 8 characters',
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
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
                              onSubmitted: (_) {
                                if (!busy) _signInWithEmailPassword();
                              },
                            ),
                            const SizedBox(height: 24),
                            AmethystButton(
                              label: busy ? 'Signing in…' : 'Sign in',
                              height: 54,
                              onTap: busy ? null : _signInWithEmailPassword,
                            ),
                            const SizedBox(height: 22),
                            const AuthDivider(text: 'or continue with'),
                            const SizedBox(height: 16),
                            AuthSocialRow(
                              onGoogle: busy ? null : _signInWithGoogle,
                              onApple: busy ? null : _signInWithApple,
                            ),
                            const SizedBox(height: 16),
                            const Spacer(),
                            AuthFooterLink(text: 'New to Sophia? ', action: 'Create account', onTap: _openRegister),
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
