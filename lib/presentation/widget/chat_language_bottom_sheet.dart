import 'package:girlfriend/core/haptics.dart';
import 'package:flutter/material.dart';
import 'package:girlfriend/presentation/widget/sophia_toast.dart';
import 'package:girlfriend/core/colors.dart';
import 'package:girlfriend/data/api_service/api_caller.dart';
import 'package:girlfriend/data/chat_language_storage.dart';
import 'package:girlfriend/presentation/view_model/user_provider.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:provider/provider.dart';

class ChatLanguageBottomSheet extends StatefulWidget {
  final String userId;
  final String? initialLanguage;
  final bool canPop;

  const ChatLanguageBottomSheet({super.key, required this.userId, this.initialLanguage, required this.canPop});

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required bool dismissible,
    String? initialLanguage,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ChatLanguageBottomSheet(userId: userId, initialLanguage: initialLanguage, canPop: dismissible);
      },
    );
  }

  @override
  State<ChatLanguageBottomSheet> createState() => _ChatLanguageBottomSheetState();
}

class _ChatLanguageBottomSheetState extends State<ChatLanguageBottomSheet> with ApiCaller {
  String _savedCode = ChatLanguageStorage.defaultCode;
  String _pendingCode = ChatLanguageStorage.defaultCode;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await ChatLanguageStorage.instance.ensureLoaded();
    if (!mounted) return;

    String initialCode = '';
    if (widget.initialLanguage != null && widget.initialLanguage!.isNotEmpty) {
      final idx = ChatLanguageStorage.options.indexWhere(
        (o) => o.englishName.toLowerCase() == widget.initialLanguage!.toLowerCase(),
      );
      if (idx >= 0) {
        initialCode = ChatLanguageStorage.options[idx].code;
      }
    }

    setState(() {
      _savedCode = initialCode;
      _pendingCode = initialCode;
      _ready = true;
    });
  }

  void _onSelectRow(ChatLanguageOption option) {
    setState(() => _pendingCode = option.code);
  }

  bool get _showApply => _ready && _pendingCode != _savedCode;

  Future<void> _onApply() async {
    if (!_showApply) return;
    final idx = ChatLanguageStorage.options.indexWhere((o) => o.code == _pendingCode);
    if (idx < 0) return;
    final option = ChatLanguageStorage.options[idx];
    final userProvider = context.read<UserProvider>();

    // Call Provider which handles API and updates local state
    final message = await userProvider.updateChatLanguage(option.englishName);

    await ChatLanguageStorage.instance.setCode(_pendingCode);
    if (!mounted) return;
    setState(() => _savedCode = _pendingCode);
    if (message != null) {
      SophiaToast.show(msg: message);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.78;

    return PopScope(
      canPop: widget.canPop,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: maxH,
          child: Container(
            decoration: BoxDecoration(
              gradient: bgGradient,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              border: Border(top: BorderSide(color: white.withValues(alpha: 0.12))),
              boxShadow: [
                BoxShadow(color: shadow.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, -8)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Text(
                      'Chat language',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  SizedBox(height: 14),
                  if (!_ready)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator(color: Colors.white)),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, _showApply ? 12 : 20),
                        itemCount: ChatLanguageStorage.options.length,
                        itemBuilder: (context, i) {
                          final o = ChatLanguageStorage.options[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _LanguageRow(
                              option: o,
                              selected: _pendingCode == o.code,
                              onTap: () => _onSelectRow(o),
                            ),
                          );
                        },
                      ),
                    ),
                  if (_showApply)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: GestureDetector(
                        onTap: Haptics.wrap(_onApply),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: btnGradient,
                            border: Border.all(color: white.withValues(alpha: 0.5), width: 1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            'Apply',
                            style: TextStyle(color: white, fontSize: 16, fontWeight: FontWeight.w700),
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
}

class _LanguageRow extends StatelessWidget {
  final ChatLanguageOption option;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageRow({required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: Haptics.wrap(onTap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: darkPurple.withValues(alpha: selected ? 0.55 : 0.45),
          borderRadius: BorderRadius.circular(50),
          border: GradientBoxBorder(
            gradient: LinearGradient(
              colors: selected
                  ? [extraLightViolet, lightViolet]
                  : [white.withValues(alpha: 0.5), extraLightViolet.withValues(alpha: 0.5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 10),
            Text(
              option.englishName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            Spacer(),
            if (selected)
              Icon(Icons.check_circle_rounded, color: extraLightViolet, size: 26)
            else
              Icon(Icons.circle_outlined, color: gray.withValues(alpha: 0.5), size: 24),
          ],
        ),
      ),
    );
  }
}
