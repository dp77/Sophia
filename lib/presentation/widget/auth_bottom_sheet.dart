import 'package:girlfriend/core/haptics.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:girlfriend/presentation/widget/sophia_toast.dart';
import 'package:provider/provider.dart';
import '../../core/app_config.dart';
import '../../core/colors.dart';
import '../view_model/auth_provider.dart';
import '../view_model/chat_list_provider.dart';
import '../view_model/user_provider.dart';

class AuthBottomSheet extends StatelessWidget {
  final VoidCallback? onSuccess;
  final VoidCallback? onError;

  const AuthBottomSheet({super.key, this.onSuccess, this.onError});

  static void show({required BuildContext context, VoidCallback? onSuccess, VoidCallback? onError}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (builderContext) => AuthBottomSheet(onSuccess: onSuccess, onError: onError),
    );
  }

  /// Convenience helper - same as show() for backward compatibility
  static void showWithDefaultClient({required BuildContext context, VoidCallback? onSuccess, VoidCallback? onError}) {
    show(context: context, onSuccess: onSuccess, onError: onError);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAnonymous = authProvider.isAnonymous;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Text(
              isAnonymous ? 'Link Your Account' : 'Continue with your account',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 8),
            Text(
              isAnonymous
                  ? 'Link your account to save your progress and access it on any device'
                  : 'Choose a sign-in option to continue',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.4),
            ),
            const SizedBox(height: 24),
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                final userProvider = Provider.of<UserProvider>(context, listen: false);

                Future<void> handleResult(Future<void> Function() action) async {
                  await action();
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: Haptics.wrap(authProvider.isSigningIn
                          ? null
                          : () {
                              handleResult(() async {
                                final chatListProvider = context.read<ChatListProvider>();
                                await authProvider.signInWithGoogle(
                                  webClientId: AppConfig.googleWebClientId,
                                  userProvider: userProvider,
                                  chatListProvider: chatListProvider,
                                  onSuccess: (msg) {
                                    if (context.mounted) {
                                      SophiaToast.show(msg: msg);
                                      Navigator.pop(context);
                                      onSuccess?.call();
                                    }
                                  },
                                  onError: (msg) {
                                    if (context.mounted) {
                                      SophiaToast.show(msg: msg);
                                      Navigator.pop(context);
                                      onError?.call();
                                    }
                                  },
                                );
                              });
                            }),
                      child: _AuthButton(
                        leading: Text(
                          'G',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22),
                        ),
                        label: 'Continue with Google',
                        isLoading: false,
                        darkBorder: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (Platform.isIOS) ...[
                      GestureDetector(
                        onTap: Haptics.wrap(authProvider.isSigningIn
                            ? null
                            : () => handleResult(() async {
                                final chatListProvider = context.read<ChatListProvider>();
                                await authProvider.signInWithApple(
                                  userProvider: userProvider,
                                  chatListProvider: chatListProvider,
                                  onSuccess: (message) {
                                    Navigator.pop(context);
                                    SophiaToast.show(msg: message);
                                    onSuccess?.call();
                                  },
                                  onError: (error) {
                                    SophiaToast.show(msg: error);
                                    onError?.call();
                                  },
                                );
                              })),
                        child: const _AuthButton(
                          leading: Text(
                            '',
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22),
                          ),
                          label: 'Continue with Apple',
                          darkBorder: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: Haptics.wrap(() => Navigator.pop(context)),
              child: const Text('Cancel', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final Widget leading;
  final String label;
  final bool isLoading;
  final bool darkBorder;

  const _AuthButton({required this.leading, required this.label, this.isLoading = false, this.darkBorder = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: darkBorder ? Colors.black : white, width: 1.5),
        color: Colors.white,
      ),
      child: isLoading
          ? Center(child: ExpressiveLoadingIndicator(color: darkBorder ? Colors.black : white))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                leading,
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: darkBorder ? Colors.black87 : Colors.black,
                  ),
                ),
              ],
            ),
    );
  }
}
