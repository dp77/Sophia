import 'package:girlfriend/core/haptics.dart';
import 'package:flutter/material.dart';
import 'package:girlfriend/data/analytics/analytics_service.dart';
import 'package:girlfriend/data/chat_language_storage.dart';
import 'package:girlfriend/presentation/view_model/user_provider.dart';
import 'package:girlfriend/presentation/widget/sophia_style.dart';
import 'package:girlfriend/presentation/widget/sophia_toast.dart';
import 'package:grokbot_widget/grokbot_widget.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';

/// "About you" — name, age, gender and chat language in one place.
///
/// * Onboarding ([isOnboarding] = true): four short steps with a progress bar.
///   It can't be dismissed until finished (replaces the old name + language sheets).
/// * Settings ([isOnboarding] = false): every section on one page with a Save button.
class AboutYouScreen extends StatefulWidget {
  final bool isOnboarding;
  const AboutYouScreen({super.key, this.isOnboarding = false});

  static Future<void> open(BuildContext context, {bool isOnboarding = false}) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => AboutYouScreen(isOnboarding: isOnboarding),
        transitionsBuilder: (_, anim, _, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<AboutYouScreen> createState() => _AboutYouScreenState();
}

class _Gender {
  final String id;
  final String label;
  final IconData icon;
  const _Gender(this.id, this.label, this.icon);
}

const _genders = [
  _Gender('man', 'Man', Icons.male_rounded),
  _Gender('woman', 'Woman', Icons.female_rounded),
  _Gender('nonbinary', 'Non-binary', Icons.transgender_rounded),
  _Gender('private', 'Prefer not to say', Icons.lock_outline_rounded),
];

const _minAge = 18;
const _maxAge = 80;

class _AboutYouScreenState extends State<AboutYouScreen> {
  final _nameCtrl = TextEditingController();
  final _pages = PageController();
  late FixedExtentScrollController _ageWheel;
  int _step = 0;
  int _age = 22;
  String _gender = '';
  String _langCode = '';
  bool _langReady = false;
  bool _saving = false;

  // Originals, to know what changed in edit mode.
  String _origName = '';
  int _origAge = 0;
  String _origGender = '';
  String _origLang = '';

  static const _stepTitles = ['What should she call you?', 'How old are you?', 'You are…', 'Chat language'];
  static const _stepHints = [
    'This is the name your companion will use.',
    'You must be 18 or older to use Sophia.',
    'Helps your companion talk to you the right way.',
    'She will reply in this language.',
  ];

  @override
  void initState() {
    super.initState();
    final up = context.read<UserProvider>();
    AnalyticsService.instance.screen(
      screenName: 'AboutYouScreen',
      innerScreenName: 'NameStep',
      context: widget.isOnboarding ? 'onboarding' : 'settings',
    );
    _origName = up.name == 'Anonymous' ? '' : up.name;
    _nameCtrl.text = _origName;
    _origAge = up.age;
    _age = up.age == 0 ? 22 : up.age;
    _origGender = up.gender;
    _gender = up.gender;
    _ageWheel = FixedExtentScrollController(initialItem: _age - _minAge);
    _nameCtrl.addListener(() => setState(() {}));
    _loadLanguage(up.chatLanguage);
  }

  Future<void> _loadLanguage(String english) async {
    await ChatLanguageStorage.instance.ensureLoaded();
    final idx = ChatLanguageStorage.options.indexWhere((o) => o.englishName.toLowerCase() == english.toLowerCase());
    if (!mounted) return;
    setState(() {
      _origLang = idx >= 0 ? ChatLanguageStorage.options[idx].code : '';
      _langCode = _origLang;
      _langReady = true;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pages.dispose();
    _ageWheel.dispose();
    super.dispose();
  }

  String get _name => _nameCtrl.text.trim();
  bool get _nameOk => _name.isNotEmpty && _name != 'Anonymous';

  bool _stepOk(int s) => switch (s) {
    0 => _nameOk,
    1 => _age >= _minAge,
    2 => _gender.isNotEmpty,
    _ => _langCode.isNotEmpty,
  };

  bool get _dirty =>
      _name != _origName || _age != _origAge || _gender != _origGender || _langCode != _origLang;

  GrokBotState get _botState {
    if (_saving) return GrokBotState.sending;
    if (widget.isOnboarding) {
      return const [GrokBotState.curious, GrokBotState.listening, GrokBotState.shy, GrokBotState.happy][_step];
    }
    return _dirty ? GrokBotState.happy : GrokBotState.idle;
  }

  void _next() {
    if (!_stepOk(_step)) {
      SophiaToast.show(
        msg: const ['Please enter your name', 'Please choose your age', 'Please choose one', 'Please pick a language'][_step],
      );
      return;
    }
    FocusScope.of(context).unfocus();
    if (_step < 3) {
      _pages.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    } else {
      _save();
    }
  }

  void _back() {
    if (_step > 0) {
      _pages.previousPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_nameOk) {
      SophiaToast.show(msg: 'Please enter your name');
      return;
    }
    if (_langCode.isEmpty) {
      SophiaToast.show(msg: 'Please pick a language');
      return;
    }
    setState(() => _saving = true);
    final up = context.read<UserProvider>();
    try {
      if (_name != _origName || up.name == 'Anonymous') {
        final ok = await up.updateName(_name);
        if (!ok) {
          SophiaToast.show(msg: 'Failed to update name. Please try again.');
          return;
        }
        await OneSignal.User.addTags({'user_id': _name});
      }
      await up.updateAboutYou(age: _age, gender: _gender);
      if (_langCode != _origLang || up.chatLanguage.isEmpty) {
        final option = ChatLanguageStorage.options.firstWhere((o) => o.code == _langCode);
        final message = await up.updateChatLanguage(option.englishName);
        await ChatLanguageStorage.instance.setCode(_langCode);
        if (message != null && !widget.isOnboarding) SophiaToast.show(msg: message);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isOnboarding,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.isOnboarding) _back();
      },
      child: Scaffold(
        backgroundColor: SophiaColors.bgTop,
        body: Container(
          decoration: const BoxDecoration(gradient: SophiaColors.background),
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -1),
                radius: 1.1,
                colors: [SophiaColors.orchid.withValues(alpha: 0.22), SophiaColors.orchid.withValues(alpha: 0)],
              ),
            ),
            child: SafeArea(child: widget.isOnboarding ? _onboarding() : _editPage()),
          ),
        ),
      ),
    );
  }

  Widget _mascot({double size = 76}) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: LoopAnimation(
              duration: const Duration(seconds: 6),
              builder: (_, t, child) => Transform.rotate(angle: t * 6.283185, child: child),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [SophiaColors.champagne, SophiaColors.orchid, SophiaColors.lilac, SophiaColors.champagne],
                  ),
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                colors: [Color(0xFF2E1A16), SophiaColors.panelTop],
              ),
            ),
            alignment: Alignment.center,
            child: GrokBot(
              size: size * 0.62,
              shape: GrokBotShape.blob,
              state: _botState,
              theme: const GrokBotThemeData(bodyColor: SophiaColors.lilac, eyeColor: SophiaColors.bgBottom),
              semanticLabel: 'Sophia mascot',
            ),
          ),
        ],
      ),
    );
  }

  // ── Onboarding: 4 steps ──────────────────────────────────────────────────

  Widget _onboarding() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              AnimatedOpacity(
                opacity: _step > 0 ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Pressable(
                  onTap: _step > 0 ? _back : null,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(color: SophiaColors.lilac.withValues(alpha: 0.22)),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const SvgIcon('ic_back', color: Colors.white, size: 16),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: 5),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          height: i == _step ? 5 : 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: i > _step ? Colors.white.withValues(alpha: 0.1) : null,
                            gradient: i <= _step
                                ? const LinearGradient(colors: [SophiaColors.champagne, SophiaColors.lilac])
                                : null,
                            boxShadow: i == _step
                                ? [BoxShadow(color: SophiaColors.champagne.withValues(alpha: 0.6), blurRadius: 10)]
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 54),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _mascot(),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a),
              child: c,
            ),
          ),
          child: Padding(
            key: ValueKey(_step),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                Text(
                  'STEP 0${_step + 1}',
                  style: const TextStyle(
                    color: SophiaColors.champagne,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _stepTitles[_step],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: SophiaColors.lavender,
                    fontSize: 35,
                    height: 1.15,
                    fontWeight: FontWeight.w400,
                    fontFamily: sophiaScript,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _stepHints[_step],
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SophiaColors.muted, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Expanded(
          child: PageView(
            controller: _pages,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) {
              setState(() => _step = i);
              const steps = ['Name', 'Age', 'Gender', 'ChatLanguage'];
              AnalyticsService.instance.screen(
                screenName: 'AboutYouScreen',
                innerScreenName: '${steps[i]}Step',
                context: widget.isOnboarding ? 'onboarding' : 'settings',
              );
            },
            children: [
              _pad(_nameField(autofocus: true)),
              _pad(_agePicker()),
              _pad(_genderGrid()),
              _languageList(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: AmethystButton(
            label: _saving ? 'Saving…' : (_step < 3 ? 'Continue' : "Let's go"),
            height: 56,
            onTap: _saving ? null : _next,
            trailing: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(_step < 3 ? Icons.arrow_forward_rounded : Icons.favorite_rounded, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _pad(Widget child) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: child,
  );

  // ── Settings: one page ───────────────────────────────────────────────────

  Widget _editPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Pressable(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(color: SophiaColors.lilac.withValues(alpha: 0.22)),
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Center(child: _mascot(size: 84)),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'About you',
                  style: TextStyle(
                    color: SophiaColors.lavender,
                    fontSize: 37,
                    fontWeight: FontWeight.w400,
                    fontFamily: sophiaScript,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'Your companion uses this to talk to you.',
                  style: TextStyle(color: SophiaColors.muted, fontSize: 13),
                ),
              ),
              const SizedBox(height: 18),
              _section('Your name', _nameField()),
              _section('Age', _agePicker()),
              _section('You are', _genderGrid()),
              _section('Chat language', SizedBox(height: 300, child: _languageList(padding: EdgeInsets.zero))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: AmethystButton(
            label: _saving ? 'Saving…' : 'Save changes',
            height: 56,
            onTap: (_saving || !_dirty) ? null : _save,
            leading: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded, color: SophiaColors.champagne, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: SophiaColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  // ── Fields ───────────────────────────────────────────────────────────────

  Widget _nameField({bool autofocus = false}) {
    return TextField(
      controller: _nameCtrl,
      autofocus: autofocus,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      maxLength: 30,
      onSubmitted: (_) {
        if (widget.isOnboarding) _next();
      },
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      textAlign: widget.isOnboarding ? TextAlign.center : TextAlign.start,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        fontFamily: sophiaSerif,
      ),
      cursorColor: SophiaColors.champagne,
      decoration: InputDecoration(
        hintText: 'Your name',
        counterText: '',
        hintStyle: TextStyle(
          color: SophiaColors.muted.withValues(alpha: 0.6),
          fontSize: 24,
          fontStyle: FontStyle.italic,
          fontFamily: sophiaSerif,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: SophiaColors.lilac.withValues(alpha: 0.22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: SophiaColors.champagne.withValues(alpha: 0.8)),
        ),
      ),
    );
  }

  /// Big champagne number with a horizontal wheel underneath.
  Widget _agePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SophiaColors.lilac.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Text(
              '$_age',
              key: ValueKey(_age),
              style: const TextStyle(
                color: SophiaColors.champagne,
                fontSize: 56,
                height: 1,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                fontFamily: sophiaSerif,
              ),
            ),
          ),
          const Text('years old', style: TextStyle(color: SophiaColors.muted, fontSize: 12)),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: SophiaColors.amethyst,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: SophiaColors.champagne.withValues(alpha: 0.7)),
                  ),
                ),
                RotatedBox(
                  quarterTurns: -1,
                  child: ListWheelScrollView.useDelegate(
                    controller: _ageWheel,
                    itemExtent: 62,
                    diameterRatio: 2.4,
                    perspective: 0.004,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (i) {
                      Haptics.selection();
                      setState(() => _age = _minAge + i);
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: _maxAge - _minAge + 1,
                      builder: (context, i) {
                        final a = _minAge + i;
                        final on = a == _age;
                        return RotatedBox(
                          quarterTurns: 1,
                          child: Center(
                            child: Text(
                              '$a',
                              style: TextStyle(
                                color: on ? Colors.white : SophiaColors.lilac.withValues(alpha: 0.6),
                                fontSize: on ? 20 : 16,
                                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _genderGrid() {
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final g in _genders)
              SizedBox(
                width: w,
                child: Pressable(
                  onTap: () => setState(() => _gender = g.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    height: 92,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: _gender == g.id ? SophiaColors.amethyst : null,
                      color: _gender == g.id ? null : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _gender == g.id
                            ? SophiaColors.champagne.withValues(alpha: 0.75)
                            : SophiaColors.lilac.withValues(alpha: 0.2),
                      ),
                      boxShadow: _gender == g.id
                          ? [
                              BoxShadow(
                                color: SophiaColors.amethystMid.withValues(alpha: 0.7),
                                blurRadius: 22,
                                spreadRadius: -8,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(g.icon, color: _gender == g.id ? SophiaColors.champagne : SophiaColors.lilac, size: 22),
                            const Spacer(),
                            AnimatedScale(
                              scale: _gender == g.id ? 1 : 0,
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutBack,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(color: SophiaColors.champagne, shape: BoxShape.circle),
                                child: const Icon(Icons.check_rounded, size: 14, color: SophiaColors.bgTop),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          g.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _languageList({EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 20)}) {
    if (!_langReady) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: SophiaColors.lilac));
    }
    final options = ChatLanguageStorage.options;
    return ListView.separated(
      padding: padding.copyWith(bottom: 12),
      itemCount: options.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final o = options[i];
        final on = o.code == _langCode;
        return Pressable(
          onTap: () => setState(() => _langCode = o.code),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: on ? SophiaColors.amethyst : null,
              color: on ? null : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: on ? SophiaColors.champagne.withValues(alpha: 0.75) : SophiaColors.lilac.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? SophiaColors.bgTop.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.06),
                  ),
                  child: Text(
                    o.code.toUpperCase(),
                    style: TextStyle(
                      color: on ? SophiaColors.champagne : SophiaColors.lilac,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.nativeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      if (o.nativeName != o.englishName)
                        Text(
                          o.englishName,
                          style: TextStyle(
                            color: on ? Colors.white.withValues(alpha: 0.75) : SophiaColors.muted,
                            fontSize: 11.5,
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedScale(
                  scale: on ? 1 : 0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: SophiaColors.champagne, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, size: 15, color: SophiaColors.bgTop),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
