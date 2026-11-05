import 'package:girlfriend/core/haptics.dart';
import 'dart:core';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:girlfriend/presentation/widget/sophia_toast.dart';
import 'package:girlfriend/data/api_service/api_caller.dart';
import 'package:girlfriend/data/api_service/dio_client.dart';
import 'package:girlfriend/data/analytics/analytics_service.dart';
import 'package:girlfriend/data/navigation_service.dart';
import 'package:girlfriend/presentation/view/screens/premium_screen.dart';
import 'package:girlfriend/presentation/widget/banner_ad_widget.dart';
import 'package:girlfriend/presentation/widget/coin_widget.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:girlfriend/presentation/view_model/user_provider.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:smooth_list_view/smooth_list_view.dart';
import '../../../core/ads_code.dart';
import '../../../core/date_utils.dart';
import '../../../core/translation_helper.dart';
import '../../../data/ad_service/ad_cooldown.dart';
import '../../../data/ad_service/cascading_ad_manager.dart';
import '../../../data/notification_helper.dart';
import '../../../data/rate_prompt.dart';
import '../../../data/model/chat_message.dart';
import '../../view_model/chat_list_provider.dart';
import '../../view_model/message_provider.dart';
import '../../view_model/watch_earn_status.dart';
import '../../widget/sophia_dialog.dart';
import '../../widget/sophia_style.dart';
import '../../widget/sophia_skeleton.dart';
import 'package:grokbot_widget/grokbot_widget.dart';
import 'image_full_screen.dart';
class ChatScreen extends StatefulWidget {
  final String imageUrl;
  final String name;
  final String companionId;

  const ChatScreen({
    required this.imageUrl,
    required this.name,
    required this.companionId,
    super.key,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const double _kChatImageWidth = 200;
  static const double _kChatImageHeight = _kChatImageWidth * 4 / 3;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final MessageProvider _messageProvider;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen(
      screenName: 'ChatScreen',
      innerScreenName: 'Conversation',
      context: 'companion_chat',
    );
    _messageProvider = Provider.of<MessageProvider>(context, listen: false);
    _checkAdAndNotificationTrigger(isMessageSend: false);
    OneSignal.Notifications.clearAll();
    NotificationHelper.isOnChatScreen = true;
    NotificationHelper.currentCompanionId = widget.companionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<UserProvider>(context, listen: false);
      _messageProvider.setUserForBalanceRefresh(user);
      _messageProvider.setChatScreenActive(true);
      Future.delayed(Duration(milliseconds: 1500), () {
        if (mounted) _incrementOpenCount();
      });
      final userId = user.id;
      if (userId.isNotEmpty) {
        _messageProvider.loadMessages(widget.companionId, userId);
      }
    });
  }

  Future<void> _incrementOpenCount() async {
    final isPremiumUser = Provider.of<UserProvider>(
      context,
      listen: false,
    ).isPremiumUser;
    if (isPremiumUser) return;
    final prefs = await SharedPreferences.getInstance();
    int openCount = prefs.getInt('chat_open_count') ?? 0;

    openCount++;
    await prefs.setInt('chat_open_count', openCount);

    if (openCount % 5 == 0) {
      loadAndShowInterstitialAd();
    }
  }

  Future<void> _checkAdAndNotificationTrigger({
    bool isMessageSend = false,
  }) async {
    final isPremiumUser = Provider.of<UserProvider>(
      context,
      listen: false,
    ).isPremiumUser;
    final prefs = await SharedPreferences.getInstance();

    const msgCountKey = 'total_messages_sent_for_notif';
    int msgCount = prefs.getInt(msgCountKey) ?? 0;

    if (isMessageSend) {
      msgCount++;
      await prefs.setInt(msgCountKey, msgCount);
    }

    if (msgCount == 5 || (msgCount >= 30 && msgCount % 30 == 0)) {
      final hasPermission = OneSignal.Notifications.permission;
      if (!hasPermission && mounted) {
        _showNotificationPermissionDialog();
      }
    }

    if (isMessageSend && !isPremiumUser) {
      const adMsgCountKey = 'global_ad_message_count';
      int adMsgCount = prefs.getInt(adMsgCountKey) ?? 0;
      adMsgCount++;

      if (adMsgCount >= 12) {
        adMsgCount = 0;
        loadAndShowInterstitialAd();
      }
      await prefs.setInt(adMsgCountKey, adMsgCount);
    }
  }

  void _showNotificationPermissionDialog() {
    showSophiaDialog(
      context: context,
      dismissible: false,
      builder: (dialogContext) => SophiaDialog(
        hero: const SophiaMascotHero(state: GrokBotState.waking),
        title: 'Stay Notified',
        message: 'Let her reach you instantly with sweet updates and messages.',
        actions: [
          AmethystButton(
            label: 'Turn On',
            leading: const Icon(
              Icons.notifications_active_rounded,
              color: SophiaColors.champagne,
              size: 18,
            ),
            onTap: () async {
              Navigator.pop(dialogContext);
              final hasPermission = OneSignal.Notifications.permission;
              if (!hasPermission) {
                await OneSignal.Notifications.requestPermission(true);
              }
              if (!mounted) return;
              await OneSignal.User.addTags({
                'user_id': Provider.of<UserProvider>(context, listen: false).id,
                'companion_id': widget.companionId,
              });
            },
          ),
          SophiaGhostButton(
            label: 'Later',
            onTap: () {
              Navigator.pop(dialogContext);
              SophiaToast.show(
                msg: "You can enable notifications anytime from Settings.",
                duration: const Duration(seconds: 4),
              );
            },
          ),
        ],
      ),
    );
  }

  void loadAndShowInterstitialAd() {
    final isPremiumUser = Provider.of<UserProvider>(
      context,
      listen: false,
    ).isPremiumUser;
    if (isPremiumUser) return;
    InterstitialAd.load(
      adUnitId: idInterstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              AdCooldown.markAdShown();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (error) {},
      ),
    );
  }

  @override
  void dispose() {
    _messageProvider.setUserForBalanceRefresh(null);
    _messageProvider.setChatScreenActive(false);
    NotificationHelper.isOnChatScreen = false;
    NotificationHelper.currentCompanionId = null;
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  final ApiCaller apiCaller = ApiCaller();

  String _resolveImagePath(String path) {
    final value = path.trim();
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    final base = Uri.tryParse(DioClient.dio.options.baseUrl);
    if (base == null) return value;
    return base.resolve(value).toString();
  }

  void _openImageViewer({required String imageUrl}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        transitionDuration: Duration(milliseconds: 260),
        reverseTransitionDuration: Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => ImageFullScreen(imageUrl: imageUrl),
      ),
    );
  }

  Future<void> _sendMessage(bool isTyping) async {
    if (isTyping || _isSending) return;
    final messageProv = Provider.of<MessageProvider>(context, listen: false);
    final chatListProv = Provider.of<ChatListProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _isSending = true;

    try {
      final bool isConnected = await InternetConnection().hasInternetAccess;
      if (!isConnected) {
        SophiaToast.show(
          msg:
              "No internet connection. Please check your connection and try again.",
        );
        return;
      }

      if (!userProvider.canSendMessage) {
        if (mounted) {
          if (Platform.isAndroid) {
            await Navigator.push(
              context,
              BottomScreenTransition(PremiumScreen()),
            );
          } else {
            await Navigator.push(
              context,
              CupertinoPageRoute(builder: (context) => PremiumScreen()),
            );
          }
        }
        await _showOutOfCreditsDialog(userProvider);
        return;
      }

      AnalyticsService.instance.event(
        'message_sent',
        screenName: 'ChatScreen',
        innerScreenName: 'Conversation',
        context: 'companion_chat',
      );
      _checkAdAndNotificationTrigger(isMessageSend: true);
      messageProv.sendMessage(
        userId: userProvider.id,
        companionId: widget.companionId,
        text: text,
        name: widget.name,
        imageUrl: widget.imageUrl,
        chatListProvider: chatListProv,
        userProvider: userProvider,
      );
      _textController.clear();
    } finally {
      _isSending = false;
    }
  }

  /// After the 5th message of a session: wait for her reply to land, give the
  /// user a moment to read it, then (maybe) show the store review sheet.
  Future<void> _askReviewAfterReply() async {
    for (var i = 0; i < 60; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      if (!_messageProvider.isTyping(widget.companionId)) break;
    }
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    await RatePrompt.maybePromptInChat(
      context,
      isBusy: () =>
          _messageProvider.isTyping(widget.companionId) ||
          _textController.text.trim().isNotEmpty,
    );
  }

  static final _photoAsk = RegExp(
    r'\b(photo|pic|picture|selfie|image|snap)',
    caseSensitive: false,
  );
  static final _balanceHint = RegExp(r'\b(balance|credits?)\b', caseSensitive: false);

  /// Her latest reply came without a photo, and either the user's last message
  /// asked for one or she mentioned their balance (the server's "balance is low" reply).
  bool _photoRefused(List<ChatMessage> messages) {
    if (messages.isEmpty) return false;
    final last = messages.last;
    if (last.isMe || last.imagePath.trim().isNotEmpty) return false;
    final status = last.imageStatus.trim().toLowerCase();
    if (status == 'pending' || status == 'processing' || status == 'completed') {
      return false;
    }
    if (_balanceHint.hasMatch(last.text) || _balanceHint.hasMatch(last.extraMessage)) {
      return true;
    }
    for (var i = messages.length - 2; i >= 0; i--) {
      if (messages[i].isMe) return _photoAsk.hasMatch(messages[i].text);
    }
    return false;
  }

  void _openPremium() {
    if (Platform.isAndroid) {
      Navigator.push(context, BottomScreenTransition(PremiumScreen()));
    } else {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (context) => PremiumScreen()),
      );
    }
  }

  Future<void> _showOutOfCreditsDialog(UserProvider userProvider) async {
    final watchEarnStatus = Provider.of<WatchEarnStatusProvider>(
      context,
      listen: false,
    );
    final remainingToday = await watchEarnStatus.watchAndEarnStatus(
      userProvider.id,
    );
    if (!mounted) return;
    if (remainingToday == null || remainingToday <= 0) return;
    final perAd = watchEarnStatus.creditsPerWatch;
    final earnText = perAd == null ? 'earn credits' : 'earn $perAd credits';

    showSophiaDialog(
      context: context,
      builder: (ctx) => SophiaDialog(
        hero: const SophiaMascotHero(state: GrokBotState.drowsy),
        title: 'Out of credits',
        message:
            "You're out of credits. Watch a short ad to $earnText and keep chatting.",
        actions: [
          AmethystButton(
            label: 'Watch & earn',
            leading: const Icon(
              Icons.play_circle_fill_rounded,
              color: SophiaColors.champagne,
              size: 18,
            ),
            onTap: () async {
              final bool isConnected =
                  await InternetConnection().hasInternetAccess;
              if (isConnected) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (!mounted) return;
                CascadingAdManager.showAd(
                  context,
                  onAdClosed: () async {
                    await userProvider.watchAndEarn();
                  },
                );
              } else {
                SophiaToast.show(
                  msg:
                      "No internet connection. Please check your connection and try again.",
                );
              }
            },
          ),
          SophiaGhostButton(label: 'Later', onTap: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  void _showClearHistoryDialog() {
    showSophiaDialog(
      context: context,
      builder: (ctx) => SophiaDialog(
        tone: SophiaTone.danger,
        hero: const SophiaIconHero(
          icon: Icons.delete_sweep_rounded,
          tone: SophiaTone.danger,
        ),
        title: 'Clear chat with ${widget.name}?',
        message:
            'This will remove your entire conversation history for this companion. This action cannot be undone.',
        actions: [
          SophiaDangerButton(
            label: 'Clear',
            svg: 'ic_delete',
            onTap: () async {
              final bool isConnected =
                  await InternetConnection().hasInternetAccess;
              if (!isConnected) {
                SophiaToast.show(
                  msg:
                      "No internet connection. Please check your connection and try again.",
                );
                return;
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _clearHistory();
            },
          ),
          SophiaGhostButton(label: 'Keep', onTap: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  Future<void> _clearHistory() async {
    final messageProv = Provider.of<MessageProvider>(context, listen: false);
    final userId = Provider.of<UserProvider>(context, listen: false).id;
    final chatListProv = Provider.of<ChatListProvider>(context, listen: false);

    final success = await messageProv.clearHistory(
      userId,
      widget.companionId,
      chatListProvider: chatListProv,
    );
    if (!mounted) return;
    if (success) {
      SophiaToast.show(msg: "History cleared");
    } else {
      SophiaToast.show(msg: 'Failed to clear history');
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: SophiaColors.bgTop,
      body: _ChatBackdrop(
        imageUrl: widget.imageUrl,
        child: Column(
          children: [
            _buildHeader(context),
            Selector<UserProvider, bool>(
              selector: (p0, userProvider) => userProvider.isPremiumUser,
              builder: (context, isPremiumUser, _) {
                return isPremiumUser
                    ? const SizedBox()
                    : BannerAdWidget(height: 50);
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                // Free users get the premium tile as the newest item in the chat when they're
                // out of credits, or when she just couldn't send a photo they can't afford.
                child: Selector<UserProvider, ({bool outOfCredits, bool lowForPhoto})>(
                  selector: (_, u) => (
                    outOfCredits: !u.isPremiumUser && !u.canSendMessage,
                    lowForPhoto: !u.isPremiumUser && !u.canGenerateImage,
                  ),
                  builder: (context, credit, _) =>
                      Selector<
                        MessageProvider,
                        ({
                          bool loading,
                          bool typing,
                          List<ChatMessage> messages,
                        })
                      >(
                        selector: (_, prov) => (
                          loading: prov.loading,
                          typing: prov.isTyping(widget.companionId),
                          messages: prov.messages
                              .map(
                                (m) => ChatMessage(
                                  role: m.role,
                                  text: m.content,
                                  time: m.time,
                                  imagePath: m.imagePath,
                                  imageStatus: m.imageStatus,
                                  generationId: m.generationId,
                                  extraMessage: m.extraMessage,
                                ),
                              )
                              .toList(),
                        ),
                        shouldRebuild: (prev, next) {
                          if (prev.loading != next.loading) return true;
                          if (prev.typing != next.typing) return true;
                          if (prev.messages.length != next.messages.length) {
                            return true;
                          }

                          // Check if any message content has changed
                          for (int i = prev.messages.length - 1; i >= 0; i--) {
                            final p = prev.messages[i];
                            final n = next.messages[i];
                            if (p.text != n.text ||
                                p.imagePath != n.imagePath ||
                                p.imageStatus != n.imageStatus ||
                                p.extraMessage != n.extraMessage) {
                              return true;
                            }
                          }
                          return false;
                        },
                        builder: (context, data, child) {
                          final isLoading = data.loading;
                          final isTyping = data.typing;
                          final messages = data.messages;

                          if (isLoading) {
                            return const ChatMessagesSkeleton();
                          }
                          final photoBlocked =
                              !credit.outOfCredits &&
                              credit.lowForPhoto &&
                              _photoRefused(messages);
                          final showPremiumTile =
                              credit.outOfCredits || photoBlocked;
                          final premiumTile = _PremiumChatTile(
                            name: widget.name,
                            imageUrl: widget.imageUrl,
                            forPhoto: photoBlocked,
                            onTap: _openPremium,
                          );
                          if (messages.isEmpty) {
                            final sayHi = Center(
                              child: _SayHiChip(
                                text: TranslationHelper.getSayHiText(
                                  context.read<UserProvider>().chatLanguage,
                                  widget.name,
                                ),
                                onTap: () {
                                  if (_isSending) return;
                                  setState(() {
                                    _textController
                                        .text = TranslationHelper.getHeyyText(
                                      context.read<UserProvider>().chatLanguage,
                                    );
                                  });
                                  _sendMessage(isTyping);
                                },
                              ),
                            );
                            if (!showPremiumTile) return sayHi;
                            return Column(
                              children: [
                                Expanded(child: sayHi),
                                premiumTile,
                              ],
                            );
                          }
                          final tileCount = showPremiumTile ? 1 : 0;
                          return SmoothListView.separated(
                            controller: _scrollController,
                            itemCount:
                                messages.length +
                                (isTyping ? 1 : 0) +
                                tileCount,
                            reverse: true,
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            itemBuilder: (context, index) {
                              if (showPremiumTile && index == 0) {
                                return premiumTile;
                              }
                              final i = index - tileCount;
                              if (isTyping && i == 0) {
                                return const _TypingBubble();
                              }
                              final msg =
                                  messages[messages.length -
                                      1 -
                                      i +
                                      (isTyping ? 1 : 0)];
                              bool showDate = false;
                              if (i ==
                                  messages.length - 1 + (isTyping ? 1 : 0)) {
                                showDate = true;
                              } else {
                                final nextMsgIndex =
                                    messages.length -
                                    1 -
                                    (i + 1) +
                                    (isTyping ? 1 : 0);
                                if (nextMsgIndex >= 0) {
                                  final nextMsg = messages[nextMsgIndex];
                                  if (!DateUtilsHelper.isSameDay(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      msg.time * 1000,
                                    ),
                                    DateTime.fromMillisecondsSinceEpoch(
                                      nextMsg.time * 1000,
                                    ),
                                  )) {
                                    showDate = true;
                                  }
                                }
                              }
                              final imageStatus = msg.imageStatus
                                  .trim()
                                  .toLowerCase();
                              final isImagePending =
                                  imageStatus == 'pending' ||
                                  imageStatus == 'processing';
                              final isImageFailed = imageStatus == 'failed';
                              // Only messages that just arrived animate in; older ones render still while scrolling.
                              final isFresh =
                                  DateTime.now().millisecondsSinceEpoch ~/
                                          1000 -
                                      msg.time <
                                  20;
                              return _BubbleIn(
                                id: '${msg.time}-${msg.role}-${msg.text.length}-${msg.imagePath}',
                                animate: isFresh,
                                fromRight: msg.isMe,
                                child: Column(
                                  crossAxisAlignment: msg.isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    if (showDate)
                                      Center(
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: SophiaColors.bgTop
                                                .withValues(alpha: 0.55),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: SophiaColors.lilac
                                                  .withValues(alpha: 0.2),
                                            ),
                                          ),
                                          child: Text(
                                            DateUtilsHelper.formatChatDate(
                                              DateTime.fromMillisecondsSinceEpoch(
                                                msg.time * 1000,
                                              ),
                                            ),
                                            style: const TextStyle(
                                              color: SophiaColors.lilac,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (msg.imagePath.trim().isNotEmpty ||
                                        isImagePending) ...[
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: GestureDetector(
                                          onTap: Haptics.wrap(() {
                                            if (isImagePending ||
                                                msg.imagePath.trim().isEmpty) {
                                              return;
                                            }
                                            final resolvedUrl =
                                                _resolveImagePath(
                                                  msg.imagePath,
                                                );
                                            _openImageViewer(
                                              imageUrl: resolvedUrl,
                                            );
                                          }),
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                              border: Border.all(
                                                color: SophiaColors.champagne
                                                    .withValues(alpha: 0.6),
                                                width: 1.2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.6),
                                                  blurRadius: 24,
                                                  spreadRadius: -10,
                                                  offset: const Offset(0, 12),
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(21),
                                              child: Shimmer(
                                                enabled: isImagePending,
                                                child: SizedBox(
                                                  width: _kChatImageWidth,
                                                  height: _kChatImageHeight,
                                                  child: Container(
                                                    width: double.infinity,
                                                    decoration:
                                                        const BoxDecoration(
                                                          gradient: SophiaColors
                                                              .background,
                                                        ),
                                                    child: isImagePending
                                                        ? Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              ExpressiveLoadingIndicator(
                                                                color:
                                                                    SophiaColors
                                                                        .lilac,
                                                              ),
                                                              const SizedBox(
                                                                height: 12,
                                                              ),
                                                              Text(
                                                                TranslationHelper.getSendingPicText(
                                                                  context
                                                                      .read<
                                                                        UserProvider
                                                                      >()
                                                                      .chatLanguage,
                                                                ),
                                                                style: const TextStyle(
                                                                  color:
                                                                      SophiaColors
                                                                          .muted,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ],
                                                          )
                                                        : isImageFailed
                                                        ? const Center(
                                                            child: Column(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .error_outline,
                                                                  color:
                                                                      SophiaColors
                                                                          .lilac,
                                                                  size: 24,
                                                                ),
                                                                SizedBox(
                                                                  height: 8,
                                                                ),
                                                                Text(
                                                                  'Image failed',
                                                                  style: TextStyle(
                                                                    color: SophiaColors
                                                                        .muted,
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          )
                                                        : CachedNetworkImage(
                                                            imageUrl:
                                                                _resolveImagePath(
                                                                  msg.imagePath,
                                                                ),
                                                            fit: BoxFit.cover,
                                                            progressIndicatorBuilder:
                                                                (
                                                                  context,
                                                                  child,
                                                                  loadingProgress,
                                                                ) {
                                                                  return Container(
                                                                    width: double
                                                                        .infinity,
                                                                    decoration: const BoxDecoration(
                                                                      gradient:
                                                                          SophiaColors
                                                                              .background,
                                                                    ),
                                                                    child: Shimmer(
                                                                      child: Center(
                                                                        child: ExpressiveLoadingIndicator(
                                                                          color:
                                                                              SophiaColors.lilac,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                            errorBuilder:
                                                                (
                                                                  context,
                                                                  error,
                                                                  stackTrace,
                                                                ) {
                                                                  return Container(
                                                                    width: double
                                                                        .infinity,
                                                                    color: Colors
                                                                        .white
                                                                        .withValues(
                                                                          alpha:
                                                                              0.05,
                                                                        ),
                                                                    child: const Center(
                                                                      child: Icon(
                                                                        Icons
                                                                            .broken_image_outlined,
                                                                        color: Colors
                                                                            .white38,
                                                                        size:
                                                                            28,
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (msg.text.trim().isNotEmpty)
                                      Container(
                                        alignment: msg.isMe
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 5,
                                        ),
                                        child: _MessageBubble(
                                          text: msg.text,
                                          isMe: msg.isMe,
                                          maxWidth: width * 0.72,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                            duration: const Duration(milliseconds: 200),
                            separatorBuilder: (BuildContext p1, int p2) {
                              return Container();
                            },
                          );
                        },
                      ),
                ),
              ),
            ),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: SophiaColors.bgTop.withValues(alpha: 0.55),
            border: Border(
              bottom: BorderSide(
                color: SophiaColors.lilac.withValues(alpha: 0.16),
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 12, 10),
              child: Row(
                children: [
                  Pressable(
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                        border: Border.all(
                          color: SophiaColors.lilac.withValues(alpha: 0.22),
                        ),
                      ),
                      padding: EdgeInsets.all(6),
                      child: const SvgIcon(
                        'ic_back',
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Pressable(
                    onTap: () => _openImageViewer(imageUrl: widget.imageUrl),
                    child: _HeaderAvatar(imageUrl: widget.imageUrl),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SophiaColors.lavender,
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            fontFamily: sophiaSerif,
                          ),
                        ),
                        Selector<MessageProvider, bool>(
                          selector: (_, prov) =>
                              prov.isTyping(widget.companionId),
                          builder: (context, isTyping, _) => AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: isTyping
                                  ? const Text(
                                      'typing…',
                                      key: ValueKey('typing'),
                                      style: TextStyle(
                                        color: SophiaColors.champagne,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  : const SizedBox(
                                      key: ValueKey('idle'),
                                      height: 0,
                                      width: double.infinity,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const CoinWidget(),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    width: 36,
                    child: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'clear_history') {
                          _showClearHistoryDialog();
                        }
                      },
                      padding: EdgeInsets.zero,
                      menuPadding: EdgeInsets.zero,
                      color: SophiaColors.panelTop,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: SophiaColors.lilac.withValues(alpha: 0.25),
                        ),
                      ),
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'clear_history',
                              child: Row(
                                children: [
                                  SvgIcon(
                                    'ic_delete',
                                    color: SophiaColors.champagne,
                                    size: 18,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Clear History',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                      icon: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                          border: Border.all(
                            color: SophiaColors.lilac.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
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

  Widget _buildComposer() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        6,
        12,
        12 + MediaQuery.paddingOf(context).bottom * 0.5,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 54,
            padding: const EdgeInsets.only(left: 18, right: 5),
            decoration: BoxDecoration(
              color: SophiaColors.panelTop.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: SophiaColors.lilac.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5),
                    cursorColor: SophiaColors.champagne,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        color: SophiaColors.muted,
                        fontSize: 14.5,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (val) {
                      final prov = Provider.of<MessageProvider>(
                        context,
                        listen: false,
                      );
                      _sendMessage(prov.isTyping(widget.companionId));
                    },
                  ),
                ),
                Selector<MessageProvider, bool>(
                  selector: (_, prov) => prov.isTyping(widget.companionId),
                  builder: (context, isTyping, child) {
                    final busy = isTyping || _isSending;
                    return ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _textController,
                      builder: (context, value, _) => _SendButton(
                        hasText: value.text.trim().isNotEmpty,
                        busy: busy,
                        onSend: () => _sendMessage(isTyping),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Chat UI pieces ─────────────────────────────────────────────────────────

/// Companion photo softly zooming behind the chat, fading into plum.
class _ChatBackdrop extends StatelessWidget {
  final String imageUrl;
  final Widget child;
  const _ChatBackdrop({required this.imageUrl, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: SophiaColors.background),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.45,
            child: LoopAnimation(
              duration: const Duration(seconds: 20),
              reverse: true,
              builder: (_, t, child) =>
                  Transform.scale(scale: 1.04 + 0.08 * t, child: child),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                alignment: Alignment.topCenter,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.25, 0.55, 0.85, 1.0],
                colors: [
                  SophiaColors.bgTop.withValues(alpha: 0.85),
                  SophiaColors.bgTop.withValues(alpha: 0.15),
                  SophiaColors.bgTop.withValues(alpha: 0.35),
                  SophiaColors.bgBottom.withValues(alpha: 0.9),
                  SophiaColors.bgBottom,
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  final String imageUrl;
  const _HeaderAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: LoopAnimation(
              duration: const Duration(seconds: 4),
              builder: (_, t, child) =>
                  Transform.rotate(angle: t * 2 * math.pi, child: child),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      SophiaColors.champagne,
                      SophiaColors.orchid,
                      SophiaColors.lilac,
                      SophiaColors.champagne,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: SophiaColors.bgTop,
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                width: 34,
                height: 34,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.person_rounded,
                  color: SophiaColors.muted,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final double maxWidth;
  const _MessageBubble({
    required this.text,
    required this.isMe,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(20);
    const tail = Radius.circular(6);
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
      decoration: BoxDecoration(
        gradient: isMe ? SophiaColors.amethyst : null,
        color: isMe ? null : SophiaColors.panelTop.withValues(alpha: 0.82),
        borderRadius: BorderRadius.only(
          topLeft: r,
          topRight: r,
          bottomLeft: isMe ? r : tail,
          bottomRight: isMe ? tail : r,
        ),
        border: Border.all(
          color: isMe
              ? Colors.white.withValues(alpha: 0.22)
              : SophiaColors.lilac.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: isMe
                ? SophiaColors.amethystMid.withValues(alpha: 0.45)
                : Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: -8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14.5,
          height: 1.4,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// New bubbles grow in from their own side; older ones render still.
class _BubbleIn extends StatefulWidget {
  final String id;
  final bool animate;
  final bool fromRight;
  final Widget child;
  const _BubbleIn({
    required this.id,
    required this.animate,
    required this.fromRight,
    required this.child,
  });

  @override
  State<_BubbleIn> createState() => _BubbleInState();
}

class _BubbleInState extends State<_BubbleIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: widget.animate ? 0 : 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutBack,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.forward();
  }

  @override
  void didUpdateWidget(covariant _BubbleIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    // List rows are reused by position, so restart when a different message lands here.
    if (oldWidget.id != widget.id) {
      if (widget.animate) {
        _c.forward(from: 0);
      } else {
        _c.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final v = _curve.value;
        return Opacity(
          opacity: _c.value,
          child: Transform.translate(
            offset: Offset(
              (widget.fromRight ? 24 : -24) * (1 - v),
              10 * (1 - v),
            ),
            child: Transform.scale(
              scale: 0.92 + 0.08 * v,
              alignment: widget.fromRight
                  ? Alignment.bottomRight
                  : Alignment.bottomLeft,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Her bubble with three champagne dots bouncing.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: _BubbleIn(
        id: 'typing',
        animate: true,
        fromRight: false,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: SophiaColors.panelTop.withValues(alpha: 0.82),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
            ),
            border: Border.all(
              color: SophiaColors.lilac.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                LoopAnimation(
                  duration: const Duration(milliseconds: 1100),
                  initial: i / 3,
                  builder: (_, t, child) {
                    final y = math.max(0.0, math.sin(t * 2 * math.pi));
                    return Transform.translate(
                      offset: Offset(0, -4 * y),
                      child: Opacity(opacity: 0.4 + 0.6 * y, child: child),
                    );
                  },
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: SophiaColors.champagne,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Premium upsell shown inside the chat when a free user is out of credits:
/// an orbiting gold edge, her photo with a lock, a blurred teaser of her next
/// message, and a gold "Unlock" pill.
class _PremiumChatTile extends StatelessWidget {
  final String name;
  final String imageUrl;
  final VoidCallback onTap;

  /// True when she just couldn't send a photo (not enough credits for one).
  final bool forPhoto;
  const _PremiumChatTile({
    required this.name,
    required this.imageUrl,
    required this.onTap,
    this.forPhoto = false,
  });

  static const _gold = Color(0xFFF6D967);
  static const _goldLight = Color(0xFFFFEB83);
  static const _ink = Color(0xFF1A0033);

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    const edge = DecoratedBox(
      decoration: BoxDecoration(
        gradient: SweepGradient(
          colors: [
            _gold,
            SophiaColors.orchid,
            SophiaColors.amethystMid,
            SophiaColors.lilac,
            _gold,
          ],
        ),
      ),
    );
    return _BubbleIn(
      id: forPhoto ? 'premium-tile-photo' : 'premium-tile',
      animate: true,
      fromRight: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
        child: Pressable(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: SophiaColors.amethystMid.withValues(alpha: 0.55),
                  blurRadius: 32,
                  spreadRadius: -12,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                children: [
                  // Slowly orbiting gold → orchid border
                  Positioned.fill(
                    child: still
                        ? edge
                        : LoopAnimation(
                            duration: const Duration(seconds: 6),
                            builder: (_, t, child) => Transform.rotate(
                              angle: t * 2 * math.pi,
                              child: Transform.scale(scale: 2.6, child: child),
                            ),
                            child: edge,
                          ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(1.4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24.6),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF2A1440),
                          SophiaColors.panelTop,
                          Color(0xFF1B0D2B),
                        ],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24.6),
                      child: Stack(
                        children: [
                          // Soft gold glow in the corner
                          Positioned(
                            top: -60,
                            right: -40,
                            child: Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    _gold.withValues(alpha: 0.22),
                                    _gold.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Positioned.fill(
                            child: SheenEffect(widthFactor: 0.25),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _lockedAvatar(),
                                    const SizedBox(width: 12),
                                    Expanded(child: _lockedTeaser()),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  forPhoto
                                      ? "Unlock $name's photos"
                                      : "Don't leave $name waiting",
                                  style: const TextStyle(
                                    color: SophiaColors.lavender,
                                    fontSize: 21,
                                    height: 1.2,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FontStyle.italic,
                                    fontFamily: sophiaSerif,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  forPhoto
                                      ? "A photo needs 20 credits and you're running low. Go Pro so she never has to hold back."
                                      : "You're out of credits. Go Pro to keep the conversation going — no limits.",
                                  style: const TextStyle(
                                    color: SophiaColors.muted,
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _PerkChip(
                                      icon: Icons.all_inclusive_rounded,
                                      label: 'Unlimited chats',
                                    ),
                                    _PerkChip(
                                      icon: Icons.favorite_rounded,
                                      label: 'More personal',
                                    ),
                                    _PerkChip(
                                      icon: Icons.auto_awesome_rounded,
                                      label: 'Remembers you',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _unlockButton(still),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _lockedAvatar() {
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 50,
            height: 50,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_goldLight, SophiaColors.orchid],
              ),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => Container(
                  color: SophiaColors.bgTop,
                  child: const Icon(
                    Icons.person_rounded,
                    color: SophiaColors.muted,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [_goldLight, _gold]),
                border: Border.all(color: SophiaColors.panelTop, width: 2),
              ),
              child: const Icon(Icons.lock_rounded, size: 11, color: _ink),
            ),
          ),
        ],
      ),
    );
  }

  /// Her next message, blurred out behind a lock.
  Widget _lockedTeaser() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${name.toUpperCase()} HAS MORE TO SAY',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _gold,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Stack(
          alignment: Alignment.center,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: const Text(
                  "I've been thinking about you all day, and there's something I really want to tell you…",
                  maxLines: 2,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: SophiaColors.bgTop.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _gold.withValues(alpha: 0.45)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 11, color: _gold),
                  SizedBox(width: 4),
                  Text(
                    'Locked',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _unlockButton(bool still) {
    final button = Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [_goldLight, _gold, Color(0xFFE2B95A)],
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.45),
            blurRadius: 20,
            spreadRadius: -6,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: const Stack(
          children: [
            Positioned.fill(child: SheenEffect(widthFactor: 0.3)),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_rounded, color: _ink, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Unlock Sophia Pro',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, color: _ink, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (still) return button;
    // Gentle breathing so the CTA catches the eye without shouting.
    return LoopAnimation(
      duration: const Duration(milliseconds: 1800),
      reverse: true,
      builder: (_, t, child) => Transform.scale(
        scale: 1 + 0.02 * Curves.easeInOut.transform(t),
        child: child,
      ),
      child: button,
    );
  }
}

class _PerkChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PerkChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SophiaColors.lilac.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: SophiaColors.champagne),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: SophiaColors.lilac,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Say hi" prompt shown before the first message.
class _SayHiChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _SayHiChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: LoopAnimation(
        duration: const Duration(milliseconds: 1800),
        reverse: true,
        builder: (_, t, child) => Transform.scale(
          scale: 1 + 0.03 * Curves.easeInOut.transform(t),
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: SophiaColors.amethyst,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: SophiaColors.amethystMid.withValues(alpha: 0.9),
                blurRadius: 30,
                spreadRadius: -12,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              children: [
                const Positioned.fill(child: SheenEffect(widthFactor: 0.3)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 20,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.waving_hand_rounded,
                        color: SophiaColors.champagne,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Send button with four looks:
/// • empty  – dim glass circle, gives a little shake if tapped
/// • ready  – pops into the amethyst gradient with a soft pulsing ring
/// • tap    – the paper plane flies off to the top-right and swoops back in
/// • busy   – a champagne arc spins around it while she is replying
class _SendButton extends StatefulWidget {
  final bool hasText;
  final bool busy;
  final VoidCallback onSend;
  const _SendButton({
    required this.hasText,
    required this.busy,
    required this.onSend,
  });

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton>
    with TickerProviderStateMixin {
  late final AnimationController _launch = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  bool get _ready => widget.hasText && !widget.busy;

  @override
  void dispose() {
    _launch.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _tap() {
    if (widget.busy) return;
    if (!widget.hasText) {
      _shake.forward(from: 0);
      return;
    }
    _launch.forward(from: 0);
    widget.onSend();
  }

  /// Plane position for the launch: out to the top-right, then back in from the bottom-left.
  Offset _planeOffset(double t) {
    if (t == 0 || t == 1) return Offset.zero;
    if (t < 0.45) {
      final p = Curves.easeIn.transform(t / 0.45);
      return Offset(26 * p, -26 * p);
    }
    final p = Curves.easeOutBack.transform((t - 0.45) / 0.55);
    return Offset(-26 * (1 - p), 26 * (1 - p));
  }

  double _planeOpacity(double t) {
    if (t < 0.35) return 1;
    if (t < 0.5) return 0;
    return ((t - 0.5) / 0.2).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Pressable(
      onTap: _tap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_launch, _shake]),
        builder: (context, _) {
          final shakeX =
              math.sin(_shake.value * math.pi * 6) * 5 * (1 - _shake.value);
          final t = reduceMotion ? 0.0 : _launch.value;
          return Transform.translate(
            offset: Offset(shakeX, 0),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Busy: spinning champagne arc
                  if (widget.busy)
                    Positioned.fill(
                      child: LoopAnimation(
                        duration: const Duration(milliseconds: 1100),
                        builder: (_, v, child) => Transform.rotate(
                          angle: v * 2 * math.pi,
                          child: child,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                SophiaColors.champagne.withValues(alpha: 0),
                                SophiaColors.champagne.withValues(alpha: 0),
                                SophiaColors.champagne,
                              ],
                              stops: const [0, 0.55, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Ready: soft pulse ring
                  if (_ready)
                    Positioned.fill(
                      child: LoopAnimation(
                        duration: const Duration(milliseconds: 1800),
                        builder: (_, v, _) => Transform.scale(
                          scale: 0.92 + 0.3 * Curves.easeOut.transform(v),
                          child: Opacity(
                            opacity: 0.6 * (1 - v),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: SophiaColors.lilac,
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  AnimatedScale(
                    scale: _ready ? 1.0 : 0.9,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutBack,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _ready ? SophiaColors.amethyst : null,
                        color: _ready
                            ? null
                            : (widget.busy
                                  ? SophiaColors.bgTop
                                  : Colors.white.withValues(alpha: 0.08)),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: _ready ? 0.3 : 0.12,
                          ),
                        ),
                        boxShadow: _ready
                            ? [
                                BoxShadow(
                                  color: SophiaColors.amethystMid.withValues(
                                    alpha: 0.85,
                                  ),
                                  blurRadius: 18,
                                  spreadRadius: -4,
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: ClipOval(
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Transform.translate(
                              offset: _planeOffset(t),
                              child: Opacity(
                                opacity: _planeOpacity(t),
                                child: AnimatedRotation(
                                  turns: _ready ? 0 : -0.06,
                                  duration: const Duration(milliseconds: 280),
                                  child: SvgPicture.asset(
                                    'assets/svg/send.svg',
                                    height: 20,
                                    width: 20,
                                    colorFilter: ColorFilter.mode(
                                      _ready ? Colors.white : Colors.white38,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
