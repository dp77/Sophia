import 'package:girlfriend/core/haptics.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:girlfriend/presentation/widget/sophia_toast.dart';
import 'package:girlfriend/data/api_service/api_caller.dart';
import 'package:girlfriend/data/navigation_service.dart';
import 'package:girlfriend/presentation/view/screens/image_full_screen.dart';
import 'package:girlfriend/presentation/view/screens/premium_screen.dart';
import 'package:girlfriend/presentation/view_model/user_character_provider.dart';
import 'package:girlfriend/presentation/view_model/user_provider.dart';
import 'package:girlfriend/presentation/widget/go_pro_widget.dart';
import 'package:girlfriend/presentation/widget/sophia_style.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:girlfriend/data/analytics/analytics_service.dart';
const List<String> _kVibeTags = [
  'Sweet',
  'Caring',
  'Flirty',
  'Playful',
  'Confident',
  'Sexy',
  'Cute',
  'Shy',
  'Mature',
  'Elegant',
  'Dominant',
  'Teasing',
  'Loyal',
  'Supportive',
];

const List<String> _kLooks = [
  'Latina',
  'Asian',
  'Blonde',
  'Brunette',
  'Goth',
  'Soft girl',
  'Gym girl',
  'Classy',
  'Girl next door',
  'Model',
];

const List<String> _kRelationships = [
  'Girlfriend',
  'Wife vibe',
  'Crush / talking stage',
  'Best friend → romance',
  'Long-distance girlfriend',
  'Protective girlfriend',
  'Possessive girlfriend',
];

const List<String> _kChatStyles = [
  'Short and cute',
  'Romantic and emotional',
  'Flirty and teasing',
  'Sexy and confident',
  'Funny and chaotic',
  'Mature and calm',
];

class CreateGirlfriendFlowScreen extends StatefulWidget {
  const CreateGirlfriendFlowScreen({super.key});

  @override
  State<CreateGirlfriendFlowScreen> createState() =>
      _CreateGirlfriendFlowScreenState();
}

class _CreateGirlfriendFlowScreenState
    extends State<CreateGirlfriendFlowScreen> {
  final ApiCaller _apiCaller = ApiCaller();
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addVibeController = TextEditingController();
  final TextEditingController _addLookController = TextEditingController();
  final TextEditingController _addRelationshipController =
      TextEditingController();
  final TextEditingController _addChatStyleController = TextEditingController();
  final FocusNode _addVibeFocus = FocusNode();
  final FocusNode _addLookFocus = FocusNode();
  final FocusNode _addRelationshipFocus = FocusNode();
  final FocusNode _addChatStyleFocus = FocusNode();
  int _page = 0;

  final Set<String> _selectedVibeTags = {};
  final List<String> _customVibeTags = [];
  bool _showAddVibeField = false;
  bool _showAddLookField = false;
  bool _showAddRelationshipField = false;
  bool _showAddChatStyleField = false;
  final List<String> _customLooks = [];
  final List<String> _customRelationships = [];
  final List<String> _customChatStyles = [];
  int _age = 22;
  String _look = '';
  String _relationship = '';
  String _chatStyle = '';
  bool _rememberDetails = true;
  int _imageSource = 2;
  String _selectedGeneratedImageUrl = '';
  final List<String> _generatedImages = [];
  bool _isGeneratingImage = false;
  bool _isCreatingCharacter = false;
  String? _referenceImagePath;
  Timer? _characterImageStatusTimer;
  bool _isCharacterStatusRequestInFlight = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen(
      screenName: 'CreateGirlfriendFlowScreen',
      innerScreenName: 'VibeStep',
      context: 'character_creation',
    );
  }

  @override
  void dispose() {
    _characterImageStatusTimer?.cancel();
    _pageController.dispose();
    _nameController.dispose();
    _addVibeController.dispose();
    _addLookController.dispose();
    _addRelationshipController.dispose();
    _addChatStyleController.dispose();
    _addVibeFocus.dispose();
    _addLookFocus.dispose();
    _addRelationshipFocus.dispose();
    _addChatStyleFocus.dispose();
    super.dispose();
  }

  void _stopCharacterImagePolling() {
    _characterImageStatusTimer?.cancel();
    _characterImageStatusTimer = null;
    _isCharacterStatusRequestInFlight = false;
  }

  Future<void> _checkCharacterImageStatus(String requestId) async {
    if (_isCharacterStatusRequestInFlight) return;
    _isCharacterStatusRequestInFlight = true;
    final result = await _apiCaller.generateImageStatus(requestId);
    if (!mounted) {
      _isCharacterStatusRequestInFlight = false;
      return;
    }
    result.fold(
      (failure) {
        _stopCharacterImagePolling();
        setState(() => _isGeneratingImage = false);
        SophiaToast.show(msg: failure.errMessage);
      },
      (response) {
        final body = response.data;
        if (body is! Map<String, dynamic>) {
          _stopCharacterImagePolling();
          setState(() => _isGeneratingImage = false);
          SophiaToast.show(msg: 'Invalid status response');
          return;
        }
        final imageUrl = (body['image_url'] ?? '').toString();
        final isCompleted = body['is_completed'] == true;
        final isGenerated = body['is_generated'] == true;
        final status = body['status'] == true;
        if (imageUrl.isNotEmpty) {
          _stopCharacterImagePolling();
          setState(() {
            _generatedImages.insert(0, imageUrl);
            _selectedGeneratedImageUrl = imageUrl;
            _isGeneratingImage = false;
          });
          return;
        }
        if (!status || (isCompleted && !isGenerated)) {
          _stopCharacterImagePolling();
          setState(() => _isGeneratingImage = false);
          final message = (body['message'] ?? 'Image generation failed')
              .toString();
          SophiaToast.show(msg: message);
          return;
        }
      },
    );
    _isCharacterStatusRequestInFlight = false;
  }

  void _startCharacterImagePolling(String requestId) {
    _stopCharacterImagePolling();
    _characterImageStatusTimer = Timer.periodic(const Duration(seconds: 10), (
      _,
    ) {
      _checkCharacterImageStatus(requestId);
    });
  }

  bool get _page0Ok =>
      _selectedVibeTags.isNotEmpty || _customVibeTags.isNotEmpty;

  List<String> get _orderedVibeTags => [
    ..._kVibeTags.where(_selectedVibeTags.contains),
    ..._customVibeTags,
  ];

  void _toggleVibeTag(String tag) {
    setState(() {
      if (_selectedVibeTags.contains(tag)) {
        _selectedVibeTags.remove(tag);
      } else {
        _selectedVibeTags.add(tag);
      }
    });
  }

  void _toggleAddVibeField() {
    setState(() {
      _showAddVibeField = !_showAddVibeField;
      if (_showAddVibeField) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _addVibeFocus.requestFocus();
        });
      } else {
        _addVibeController.clear();
      }
    });
  }

  String? _presetMatchingInput(String raw) {
    final t = raw.trim().toLowerCase();
    for (final p in _kVibeTags) {
      if (p.toLowerCase() == t) return p;
    }
    return null;
  }

  void _commitAddVibe() {
    final t = _addVibeController.text.trim();
    if (t.isEmpty) {
      SophiaToast.show(msg: 'Type a tag first');
      return;
    }
    if (t.length > 40) {
      SophiaToast.show(msg: 'Max 40 characters');
      return;
    }
    final preset = _presetMatchingInput(t);
    if (preset != null) {
      if (_selectedVibeTags.contains(preset)) {
        SophiaToast.show(msg: 'Already selected');
        return;
      }
      setState(() {
        _selectedVibeTags.add(preset);
        _addVibeController.clear();
        _showAddVibeField = false;
      });
      return;
    }
    final dup = _customVibeTags.any((x) => x.toLowerCase() == t.toLowerCase());
    if (dup) {
      SophiaToast.show(msg: 'Already added');
      return;
    }
    setState(() {
      _customVibeTags.add(t);
      _addVibeController.clear();
      _showAddVibeField = false;
    });
  }

  void _removeCustomTag(String tag) {
    setState(() => _customVibeTags.remove(tag));
  }

  void _toggleCustomField({
    required bool current,
    required ValueChanged<bool> setter,
    required FocusNode focusNode,
    required TextEditingController controller,
  }) {
    final next = !current;
    setter(next);
    if (next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focusNode.requestFocus();
      });
    } else {
      controller.clear();
    }
  }

  String? _matchPreset(String raw, List<String> presets) {
    final t = raw.trim().toLowerCase();
    for (final p in presets) {
      if (p.toLowerCase() == t) return p;
    }
    return null;
  }

  void _commitSingleSelection({
    required TextEditingController controller,
    required List<String> presets,
    required List<String> custom,
    required ValueSetter<String> setSelected,
    required ValueChanged<bool> setShowField,
    required String emptyMsg,
  }) {
    final t = controller.text.trim();
    if (t.isEmpty) {
      SophiaToast.show(msg: emptyMsg);
      return;
    }
    if (t.length > 40) {
      SophiaToast.show(msg: 'Max 40 characters');
      return;
    }
    final preset = _matchPreset(t, presets);
    if (preset != null) {
      setState(() {
        setSelected(preset);
        controller.clear();
        setShowField(false);
      });
      return;
    }
    final exists = custom.any((x) => x.toLowerCase() == t.toLowerCase());
    if (!exists) {
      custom.add(t);
    }
    setState(() {
      setSelected(t);
      controller.clear();
      setShowField(false);
    });
  }

  bool get _page1Ok => _nameController.text.trim().isNotEmpty;

  bool get _page2Ok => _look.trim().isNotEmpty;

  bool get _page3Ok => _relationship.trim().isNotEmpty;

  bool get _page4Ok => _chatStyle.trim().isNotEmpty;

  bool get _page5Ok => _generatedImages.isNotEmpty;

  String get _effectiveSelectedGeneratedImageUrl {
    if (_generatedImages.isEmpty) return '';
    if (_selectedGeneratedImageUrl.isNotEmpty &&
        _generatedImages.contains(_selectedGeneratedImageUrl)) {
      return _selectedGeneratedImageUrl;
    }
    return _generatedImages.first;
  }

  Future<void> _pickAndCropReferenceImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop image',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(title: 'Crop image'),
      ],
    );
    if (cropped == null) {
      return;
    }
    setState(() {
      _referenceImagePath = cropped.path;
    });
  }

  Future<void> _generateCharacterImage() async {
    _stopCharacterImagePolling();
    final userId =
        (await SharedPreferences.getInstance()).getString('user_backend_id') ??
        '';
    if (userId.isEmpty) {
      SophiaToast.show(msg: 'User not found');
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      SophiaToast.show(msg: 'Give her a name');
      return;
    }
    final lookVibe = <String>{_look, ..._orderedVibeTags}.toList();
    if (lookVibe.isEmpty) {
      SophiaToast.show(msg: 'Select look vibe');
      return;
    }
    final data = <String, dynamic>{
      'user_id': userId,
      'name': name,
      'age': _age,
      'traits': _orderedVibeTags,
      'look_vibe': lookVibe,
      'relationship_type': _relationship.toLowerCase(),
      'texting_style': _chatStyle,
    };
    if (_imageSource == 1) {
      if (_referenceImagePath == null || _referenceImagePath!.isEmpty) {
        SophiaToast.show(msg: 'Pick and crop reference image first');
        return;
      }
      final bytes = await File(_referenceImagePath!).readAsBytes();
      final base64Image = base64Encode(bytes);
      if (base64Image.isEmpty) {
        SophiaToast.show(msg: 'Invalid reference image');
        return;
      }
      data['reference_image'] = base64Image;
    }
    setState(() => _isGeneratingImage = true);
    final result = await _apiCaller.generateCharacterImage(data);
    if (!mounted) return;
    result.fold(
      (failure) {
        _stopCharacterImagePolling();
        setState(() => _isGeneratingImage = false);
        SophiaToast.show(msg: failure.errMessage);
      },
      (response) {
        final body = response.data;

        Provider.of<UserProvider>(
          context,
          listen: false,
        ).updateCredits(body['credits'] ?? 0);

        // If image is already ready, use it directly
        final imageUrl = (body['image_url'] ?? '').toString();
        if (imageUrl.isNotEmpty) {
          setState(() {
            _generatedImages.insert(0, imageUrl);
            if (_selectedGeneratedImageUrl.isEmpty) {
              _selectedGeneratedImageUrl = imageUrl;
            }
            _isGeneratingImage = false;
          });
          return;
        }

        // If a request_id came back (status: "pending"), start polling
        final requestId = (body['request_id'] ?? '').toString();
        if (requestId.isNotEmpty) {
          _startCharacterImagePolling(requestId);
          return; // keep _isGeneratingImage = true while polling
        }

        // Neither image_url nor request_id — something went wrong
        _stopCharacterImagePolling();
        setState(() => _isGeneratingImage = false);
        SophiaToast.show(
          msg: (body['message'] ?? 'Generation failed').toString(),
        );
      },
    );
  }

  void _next() {
    if (_page == 0 && !_page0Ok) {
      SophiaToast.show(msg: 'Pick a tag or add one of your own');
      return;
    }
    if (_page == 1 && !_page1Ok) {
      SophiaToast.show(msg: 'Give her a name');
      return;
    }
    if (_page == 2 && !_page2Ok) {
      SophiaToast.show(msg: 'Select look vibe');
      return;
    }
    if (_page == 3 && !_page3Ok) {
      SophiaToast.show(msg: 'Select relationship');
      return;
    }
    if (_page == 4 && !_page4Ok) {
      SophiaToast.show(msg: 'Select text style');
      return;
    }
    if (_page == 5 && !_page5Ok) {
      SophiaToast.show(msg: 'Select an image');
      return;
    }
    if (_page < 6) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _back() {
    if (_page == 0) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } else {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _create() async {
    if (_isCreatingCharacter) {
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      SophiaToast.show(msg: 'Add her name on step 2');
      return;
    }
    if (_generatedImages.isEmpty) {
      SophiaToast.show(msg: 'Generate and select image first');
      return;
    }
    final selectedImageUrl = _effectiveSelectedGeneratedImageUrl;
    if (selectedImageUrl.isEmpty) {
      SophiaToast.show(msg: 'Generate and select image first');
      return;
    }
    final userId =
        (await SharedPreferences.getInstance()).getString('user_backend_id') ??
        '';
    if (userId.isEmpty) {
      SophiaToast.show(msg: 'User not found');
      return;
    }
    final payload = <String, dynamic>{
      'user_id': userId,
      'name': name,
      'age': _age,
      'traits': _orderedVibeTags,
      'look_vibe': [_look],
      'relationship_type': _relationship.toLowerCase(),
      'texting_style': _chatStyle,
      'generated_image_url': selectedImageUrl,
    };
    setState(() => _isCreatingCharacter = true);
    final result = await _apiCaller.createCharacter(payload);
    if (!mounted) return;
    result.fold(
      (failure) {
        setState(() => _isCreatingCharacter = false);
        SophiaToast.show(msg: failure.errMessage);
      },
      (response) {
        setState(() => _isCreatingCharacter = false);
        final data = response.data;
        context.read<UserCharacterProvider>().fetchCompanionsSilently();
        if (data is Map<String, dynamic>) {
          SophiaToast.show(
            msg: (data['message'] ?? 'Character created').toString(),
          );
        } else {
          SophiaToast.show(msg: 'Character created');
        }
        Navigator.pop(context, true);
      },
    );
  }

  static const _stepNames = [
    'Her vibe',
    'Name & age',
    'Look',
    'Relationship',
    'Texting style',
    'Her photo',
    'Review',
  ];

  @override
  Widget build(BuildContext context) {
    final step = _page + 1;
    return Container(
      decoration: const BoxDecoration(gradient: SophiaColors.background),
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(1, -1),
            radius: 1.1,
            colors: [
              SophiaColors.orchid.withValues(alpha: 0.22),
              SophiaColors.orchid.withValues(alpha: 0),
            ],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leadingWidth: 64,
            leading: Center(
              child: Pressable(
                onTap: _back,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: _glass(radius: 20),
                  padding: const EdgeInsets.all(6),
                  child: const SvgIcon('ic_back', color: Colors.white, size: 16),
                ),
              ),
            ),
            title: Column(
              children: [
                const Text(
                  'Create Your Partner',
                  style: TextStyle(
                    color: SophiaColors.lavender,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    fontFamily: sophiaSerif,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    'Step $step of 7 · ${_stepNames[_page]}',
                    key: ValueKey(_page),
                    style: const TextStyle(
                      color: SophiaColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              Consumer<UserProvider>(
                builder: (context, u, _) {
                  if (u.isPremiumUser) return const SizedBox(width: 8);
                  return const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: GoProWidget(),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: _StepProgress(current: _page, total: 7),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) {
                    setState(() => _page = i);
                    const pages = [
                      'Vibe',
                      'NameAge',
                      'Look',
                      'Relationship',
                      'ChatStyle',
                      'ImageSelection',
                      'Preview',
                    ];
                    AnalyticsService.instance.screen(
                      screenName: 'CreateGirlfriendFlowScreen',
                      innerScreenName: '${pages[i]}Step',
                      context: 'character_creation',
                    );
                  },
                  children: [
                    _PageVibe(
                      selected: _selectedVibeTags,
                      customTags: _customVibeTags,
                      showAddField: _showAddVibeField,
                      addController: _addVibeController,
                      addFocus: _addVibeFocus,
                      onToggleTag: _toggleVibeTag,
                      onToggleAddField: _toggleAddVibeField,
                      onCommitAddTag: _commitAddVibe,
                      onRemoveCustomTag: _removeCustomTag,
                    ),
                    _PageNameAge(
                      nameController: _nameController,
                      age: _age,
                      onAge: (a) => setState(() => _age = a),
                    ),
                    _PageSingleSelection(
                      eyebrow: 'Step 03',
                      title: 'Her look',
                      subtitle:
                          'Pick one. You can also add your own custom look vibe.',
                      options: [..._kLooks, ..._customLooks],
                      selected: _look,
                      showAddField: _showAddLookField,
                      addController: _addLookController,
                      addFocus: _addLookFocus,
                      addHint: 'Add custom look vibe',
                      onSelect: (value) => setState(() => _look = value),
                      onToggleAddField: () => setState(() {
                        _toggleCustomField(
                          current: _showAddLookField,
                          setter: (v) => _showAddLookField = v,
                          focusNode: _addLookFocus,
                          controller: _addLookController,
                        );
                      }),
                      onCommitAdd: () => _commitSingleSelection(
                        controller: _addLookController,
                        presets: _kLooks,
                        custom: _customLooks,
                        setSelected: (value) => _look = value,
                        setShowField: (v) => _showAddLookField = v,
                        emptyMsg: 'Type look vibe first',
                      ),
                    ),
                    _PageSingleSelection(
                      eyebrow: 'Step 04',
                      title: 'Your bond',
                      subtitle:
                          'Pick one. You can also add your own custom relationship.',
                      options: [..._kRelationships, ..._customRelationships],
                      selected: _relationship,
                      showAddField: _showAddRelationshipField,
                      addController: _addRelationshipController,
                      addFocus: _addRelationshipFocus,
                      addHint: 'Add custom relationship',
                      onSelect: (value) =>
                          setState(() => _relationship = value),
                      onToggleAddField: () => setState(() {
                        _toggleCustomField(
                          current: _showAddRelationshipField,
                          setter: (v) => _showAddRelationshipField = v,
                          focusNode: _addRelationshipFocus,
                          controller: _addRelationshipController,
                        );
                      }),
                      onCommitAdd: () => _commitSingleSelection(
                        controller: _addRelationshipController,
                        presets: _kRelationships,
                        custom: _customRelationships,
                        setSelected: (value) => _relationship = value,
                        setShowField: (v) => _showAddRelationshipField = v,
                        emptyMsg: 'Type relationship first',
                      ),
                    ),
                    _PageSingleSelection(
                      eyebrow: 'Step 05',
                      title: 'How should she text?',
                      subtitle:
                          'Pick one. You can also add your own custom text style.',
                      options: [..._kChatStyles, ..._customChatStyles],
                      selected: _chatStyle,
                      showAddField: _showAddChatStyleField,
                      addController: _addChatStyleController,
                      addFocus: _addChatStyleFocus,
                      addHint: 'Add custom text style',
                      onSelect: (value) => setState(() => _chatStyle = value),
                      onToggleAddField: () => setState(() {
                        _toggleCustomField(
                          current: _showAddChatStyleField,
                          setter: (v) => _showAddChatStyleField = v,
                          focusNode: _addChatStyleFocus,
                          controller: _addChatStyleController,
                        );
                      }),
                      onCommitAdd: () => _commitSingleSelection(
                        controller: _addChatStyleController,
                        presets: _kChatStyles,
                        custom: _customChatStyles,
                        setSelected: (value) => _chatStyle = value,
                        setShowField: (v) => _showAddChatStyleField = v,
                        emptyMsg: 'Type text style first',
                      ),
                    ),
                    _PageImageSelection(
                      selectedSource: _imageSource,
                      generatedImages: _generatedImages,
                      isGenerating: _isGeneratingImage,
                      referenceImagePath: _referenceImagePath,
                      selectedGeneratedImageUrl:
                          _effectiveSelectedGeneratedImageUrl,
                      onSourceChanged: (v) => setState(() => _imageSource = v),
                      onPickReferenceImage: _pickAndCropReferenceImage,
                      onRegenerate: _generateCharacterImage,
                      onSelectGenerated: (imageUrl) =>
                          setState(() => _selectedGeneratedImageUrl = imageUrl),
                    ),
                    _PagePreview(
                      vibeTags: _orderedVibeTags,
                      name: _nameController.text.trim(),
                      age: _age,
                      look: _look,
                      relationship: _relationship,
                      chatStyle: _chatStyle,
                      selectedImageUrl: _effectiveSelectedGeneratedImageUrl,
                      rememberDetails: _rememberDetails,
                      isCreating: _isCreatingCharacter,
                      onRemember: (v) => setState(() => _rememberDetails = v),
                      onCreate: _create,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Pressable(
                        onTap: _back,
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: _glass(radius: 26),
                          child: Text(
                            _page == 0 ? 'Cancel' : 'Back',
                            style: const TextStyle(
                              color: SophiaColors.lilac,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_page < 6) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: AmethystButton(
                          label: 'Next',
                          onTap: _next,
                          trailing: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared pieces ──────────────────────────────────────────────────────────

BoxDecoration _glass({double radius = 18, bool active = false}) =>
    BoxDecoration(
      color: Colors.white.withValues(alpha: active ? 0.08 : 0.05),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: active
            ? SophiaColors.champagne.withValues(alpha: 0.7)
            : SophiaColors.lilac.withValues(alpha: 0.22),
      ),
    );

class _StepProgress extends StatelessWidget {
  final int current;
  final int total;
  const _StepProgress({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              height: i == current ? 5 : 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: i > current ? Colors.white.withValues(alpha: 0.1) : null,
                gradient: i <= current
                    ? const LinearGradient(
                        colors: [SophiaColors.champagne, SophiaColors.lilac],
                      )
                    : null,
                boxShadow: i == current
                    ? [
                        BoxShadow(
                          color: SophiaColors.champagne.withValues(alpha: 0.6),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Step title block; slides in each time the page is built.
class _StepHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  const _StepHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SlideEntrance(
      delay: 60,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              color: SophiaColors.champagne,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: SophiaColors.lavender,
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              fontFamily: sophiaSerif,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: SophiaColors.muted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? SophiaColors.amethyst : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? SophiaColors.champagne.withValues(alpha: 0.75)
                : SophiaColors.lilac.withValues(alpha: 0.22),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: SophiaColors.amethystMid.withValues(alpha: 0.7),
                    blurRadius: 18,
                    spreadRadius: -6,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: selected || icon != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        icon ?? Icons.check_rounded,
                        color: selected
                            ? SophiaColors.champagne
                            : SophiaColors.lilac,
                        size: 16,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final VoidCallback onCommit;

  const _AddField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onCommit,
  });

  @override
  Widget build(BuildContext context) {
    return SlideEntrance(
      delay: 0,
      distance: 10,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: _glass(radius: 24, active: true),
              alignment: Alignment.center,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onTapOutside: (event) => FocusScope.of(context).unfocus(),
                maxLines: 1,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onCommit(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.2,
                ),
                cursorColor: SophiaColors.champagne,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  hintText: hint,
                  hintStyle: const TextStyle(
                    color: SophiaColors.muted,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onTap: onCommit,
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                gradient: SophiaColors.amethyst,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1: vibe ───────────────────────────────────────────────────────────
class _PageVibe extends StatelessWidget {
  final Set<String> selected;
  final List<String> customTags;
  final bool showAddField;
  final TextEditingController addController;
  final FocusNode addFocus;
  final ValueChanged<String> onToggleTag;
  final VoidCallback onToggleAddField;
  final VoidCallback onCommitAddTag;
  final ValueChanged<String> onRemoveCustomTag;

  const _PageVibe({
    required this.selected,
    required this.customTags,
    required this.showAddField,
    required this.addController,
    required this.addFocus,
    required this.onToggleTag,
    required this.onToggleAddField,
    required this.onCommitAddTag,
    required this.onRemoveCustomTag,
  });

  @override
  Widget build(BuildContext context) {
    final count = selected.length + customTags.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const _StepHeading(
          eyebrow: 'Step 01',
          title: 'What kind of girlfriend do you want?',
          subtitle:
              'Tap traits to select. Use Add to type a new tag—matches a preset name or saves as yours.',
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            count == 0 ? 'Pick as many as you like' : '$count selected',
            key: ValueKey(count),
            style: TextStyle(
              color: count == 0 ? SophiaColors.muted : SophiaColors.champagne,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SlideEntrance(
          delay: 160,
          child: Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              ..._kVibeTags.map(
                (tag) => _SelectChip(
                  label: tag,
                  selected: selected.contains(tag),
                  onTap: () => onToggleTag(tag),
                ),
              ),
              _SelectChip(
                label: 'Add',
                selected: showAddField,
                icon: Icons.add_rounded,
                onTap: onToggleAddField,
              ),
            ],
          ),
        ),
        if (showAddField) ...[
          const SizedBox(height: 14),
          _AddField(
            controller: addController,
            focusNode: addFocus,
            hint: 'New tag...',
            onCommit: onCommitAddTag,
          ),
        ],
        if (customTags.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'YOUR TAGS',
            style: TextStyle(
              color: SophiaColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: customTags.map((tag) {
              return Pressable(
                onTap: () => onRemoveCustomTag(tag),
                child: Container(
                  padding: const EdgeInsets.only(
                    left: 12,
                    right: 8,
                    top: 7,
                    bottom: 7,
                  ),
                  decoration: BoxDecoration(
                    color: SophiaColors.champagne.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: SophiaColors.champagne.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tag,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.close_rounded,
                        color: SophiaColors.champagne,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ── Step 2: name & age ─────────────────────────────────────────────────────
class _PageNameAge extends StatefulWidget {
  final TextEditingController nameController;
  final int age;
  final ValueChanged<int> onAge;

  const _PageNameAge({
    required this.nameController,
    required this.age,
    required this.onAge,
  });

  @override
  State<_PageNameAge> createState() => _PageNameAgeState();
}

class _PageNameAgeState extends State<_PageNameAge> {
  static const _minAge = 18;
  static const _itemExtent = 56.0;
  late final ScrollController _ages = ScrollController(
    initialScrollOffset: math.max(
      0.0,
      (widget.age - _minAge - 2) * _itemExtent,
    ),
  );

  @override
  void dispose() {
    _ages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const _StepHeading(
          eyebrow: 'Step 02',
          title: 'Name and age',
          subtitle: 'Give her a name and choose an age.',
        ),
        const SizedBox(height: 24),
        const Text(
          'HER NAME',
          style: TextStyle(
            color: SophiaColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        SlideEntrance(
          delay: 140,
          child: TextField(
            controller: widget.nameController,
            onTapOutside: (event) => FocusScope.of(context).unfocus(),
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              fontFamily: sophiaSerif,
            ),
            cursorColor: SophiaColors.champagne,
            decoration: InputDecoration(
              hintText: 'e.g. Sophia',
              hintStyle: TextStyle(
                color: SophiaColors.muted.withValues(alpha: 0.6),
                fontSize: 22,
                fontStyle: FontStyle.italic,
                fontFamily: sophiaSerif,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: SophiaColors.lilac.withValues(alpha: 0.22),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: SophiaColors.champagne.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'AGE',
              style: TextStyle(
                color: SophiaColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Text(
                '${widget.age}',
                key: ValueKey(widget.age),
                style: const TextStyle(
                  color: SophiaColors.champagne,
                  fontSize: 40,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  fontFamily: sophiaSerif,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SlideEntrance(
          delay: 220,
          child: SizedBox(
            height: 56,
            child: ListView.builder(
              controller: _ages,
              scrollDirection: Axis.horizontal,
              itemCount: 33,
              itemExtent: _itemExtent,
              itemBuilder: (_, i) {
                final a = _minAge + i;
                final on = widget.age == a;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Pressable(
                    onTap: () => widget.onAge(a),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: on ? SophiaColors.amethyst : null,
                        color: on ? null : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: on
                              ? SophiaColors.champagne.withValues(alpha: 0.75)
                              : SophiaColors.lilac.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        '$a',
                        style: TextStyle(
                          color: on ? Colors.white : SophiaColors.lilac,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── Steps 3–5: single choice ───────────────────────────────────────────────
class _PageSingleSelection extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<String> options;
  final String selected;
  final bool showAddField;
  final TextEditingController addController;
  final FocusNode addFocus;
  final String addHint;
  final ValueChanged<String> onSelect;
  final VoidCallback onToggleAddField;
  final VoidCallback onCommitAdd;

  const _PageSingleSelection({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.showAddField,
    required this.addController,
    required this.addFocus,
    required this.addHint,
    required this.onSelect,
    required this.onToggleAddField,
    required this.onCommitAdd,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _StepHeading(eyebrow: eyebrow, title: title, subtitle: subtitle),
        const SizedBox(height: 20),
        SlideEntrance(
          delay: 160,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = (box.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in options)
                    SizedBox(
                      width: w,
                      child: _OptionTile(
                        label: item,
                        selected: selected == item,
                        onTap: () => onSelect(item),
                      ),
                    ),
                  SizedBox(
                    width: w,
                    child: _OptionTile(
                      label: addHint,
                      selected: showAddField,
                      isAdd: true,
                      onTap: onToggleAddField,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (showAddField) ...[
          const SizedBox(height: 14),
          _AddField(
            controller: addController,
            focusNode: addFocus,
            hint: addHint,
            onCommit: onCommitAdd,
          ),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isAdd;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isAdd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: selected && !isAdd ? SophiaColors.amethyst : null,
          color: selected && !isAdd
              ? null
              : Colors.white.withValues(alpha: isAdd ? 0.02 : 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? SophiaColors.champagne.withValues(alpha: 0.75)
                : SophiaColors.lilac.withValues(alpha: isAdd ? 0.35 : 0.2),
          ),
          boxShadow: selected && !isAdd
              ? [
                  BoxShadow(
                    color: SophiaColors.amethystMid.withValues(alpha: 0.75),
                    blurRadius: 22,
                    spreadRadius: -8,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            if (isAdd) ...[
              const Icon(
                Icons.add_rounded,
                color: SophiaColors.champagne,
                size: 18,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isAdd ? SophiaColors.lilac : Colors.white,
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (!isAdd)
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? SophiaColors.champagne : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? SophiaColors.champagne
                        : SophiaColors.lilac.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: SophiaColors.bgTop,
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Step 6: image ──────────────────────────────────────────────────────────
class _PageImageSelection extends StatelessWidget {
  final int selectedSource;
  final List<String> generatedImages;
  final bool isGenerating;
  final String? referenceImagePath;
  final String selectedGeneratedImageUrl;
  final ValueChanged<int> onSourceChanged;
  final VoidCallback onPickReferenceImage;
  final VoidCallback onRegenerate;
  final ValueChanged<String> onSelectGenerated;

  const _PageImageSelection({
    required this.selectedSource,
    required this.generatedImages,
    required this.isGenerating,
    required this.referenceImagePath,
    required this.selectedGeneratedImageUrl,
    required this.onSourceChanged,
    required this.onPickReferenceImage,
    required this.onRegenerate,
    required this.onSelectGenerated,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const _StepHeading(
          eyebrow: 'Step 06',
          title: 'Bring her to life',
          subtitle: 'Generate image from selected details or reference image.',
        ),
        const SizedBox(height: 20),
        SlideEntrance(
          delay: 140,
          child: Row(
            children: [
              Expanded(
                child: _ImageSourceTile(
                  icon: Icons.auto_awesome_rounded,
                  title: 'From details',
                  subtitle: 'Use selected look and vibe tags',
                  selected: selectedSource == 2,
                  onTap: () => onSourceChanged(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ImageSourceTile(
                  icon: Icons.add_photo_alternate_rounded,
                  title: 'Reference image',
                  subtitle: 'Upload a photo to guide her look',
                  selected: selectedSource == 1,
                  onTap: () => onSourceChanged(1),
                ),
              ),
            ],
          ),
        ),
        if (selectedSource == 1) ...[
          const SizedBox(height: 12),
          Pressable(
            onTap: onPickReferenceImage,
            child: Container(
              height: referenceImagePath == null ? 52 : 180,
              decoration: _glass(
                radius: 22,
                active: referenceImagePath != null,
              ),
              child: referenceImagePath == null
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.upload_rounded,
                          color: SophiaColors.champagne,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Pick and crop reference image',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : RepaintBoundary(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(21),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: 10,
                                sigmaY: 10,
                              ),
                              child: Image.file(
                                File(referenceImagePath!),
                                fit: BoxFit.cover,
                              ),
                            ),
                            Center(
                              child: Image.file(
                                File(referenceImagePath!),
                                fit: BoxFit.contain,
                              ),
                            ),
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: SophiaColors.bgTop.withValues(
                                    alpha: 0.65,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Change',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
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
        ],
        const SizedBox(height: 16),
        AmethystButton(
          label: isGenerating
              ? 'Generating...'
              : (generatedImages.isEmpty ? 'Generate' : 'Generate another'),
          onTap: isGenerating ? null : onRegenerate,
          leading: isGenerating
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: ExpressiveLoadingIndicator(color: Colors.white),
                )
              : const Icon(
                  Icons.auto_awesome_rounded,
                  color: SophiaColors.champagne,
                  size: 18,
                ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Text(
              'GENERATED IMAGES',
              style: TextStyle(
                color: SophiaColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
            const Spacer(),
            if (generatedImages.isNotEmpty)
              const Text(
                'Tap to select',
                style: TextStyle(color: SophiaColors.muted, fontSize: 11),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: generatedImages.isEmpty
              ? Container(
                  alignment: Alignment.center,
                  decoration: _glass(radius: 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      isGenerating
                          ? SizedBox(
                              width: 36,
                              height: 36,
                              child: ExpressiveLoadingIndicator(
                                color: SophiaColors.lilac,
                              ),
                            )
                          : LoopAnimation(
                              duration: const Duration(milliseconds: 2600),
                              reverse: true,
                              builder: (_, t, child) =>
                                  Opacity(opacity: 0.4 + 0.6 * t, child: child),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: SophiaColors.champagne,
                                size: 30,
                              ),
                            ),
                      const SizedBox(height: 10),
                      Text(
                        isGenerating
                            ? 'Creating her portrait…'
                            : 'No images yet',
                        style: const TextStyle(
                          color: SophiaColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: generatedImages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final image = generatedImages[i];
                    final on = image == selectedGeneratedImageUrl;
                    return Pressable(
                      onTap: () {
                        onSelectGenerated(image);
                        NavigationService.navigateToScreen(
                          context,
                          ImageFullScreen(imageUrl: image),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        width: 142,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: on
                                ? SophiaColors.champagne
                                : SophiaColors.lilac.withValues(alpha: 0.2),
                            width: on ? 1.6 : 1,
                          ),
                          boxShadow: on
                              ? [
                                  BoxShadow(
                                    color: SophiaColors.champagne.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 16,
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(21),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              image.startsWith('http')
                                  ? CachedNetworkImage(
                                      imageUrl: image,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.topCenter,
                                      errorBuilder: (_, _, _) => Container(
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.image_not_supported_rounded,
                                          color: SophiaColors.muted,
                                        ),
                                      ),
                                      progressIndicatorBuilder:
                                          (
                                            context,
                                            child,
                                            loadingProgress,
                                          ) => Container(
                                            decoration: const BoxDecoration(
                                              gradient: SophiaColors.background,
                                            ),
                                            child: Center(
                                              child: ExpressiveLoadingIndicator(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                    )
                                  : Container(
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.image_rounded,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: AnimatedScale(
                                  scale: on ? 1 : 0,
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeOutBack,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: const BoxDecoration(
                                      color: SophiaColors.champagne,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: SophiaColors.bgTop,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ImageSourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ImageSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        height: 128,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: selected ? SophiaColors.amethyst : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? SophiaColors.champagne.withValues(alpha: 0.75)
                : SophiaColors.lilac.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: selected ? SophiaColors.champagne : SophiaColors.lilac,
                  size: 22,
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? SophiaColors.champagne
                        : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? SophiaColors.champagne
                          : SophiaColors.lilac.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: SophiaColors.bgTop,
                        )
                      : null,
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? Colors.white.withValues(alpha: 0.8)
                    : SophiaColors.muted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 7: review ─────────────────────────────────────────────────────────
class _PagePreview extends StatelessWidget {
  final List<String> vibeTags;
  final String name;
  final int age;
  final String look;
  final String relationship;
  final String chatStyle;
  final String selectedImageUrl;
  final bool rememberDetails;
  final bool isCreating;
  final ValueChanged<bool> onRemember;
  final VoidCallback onCreate;

  const _PagePreview({
    required this.vibeTags,
    required this.name,
    required this.age,
    required this.look,
    required this.relationship,
    required this.chatStyle,
    required this.selectedImageUrl,
    required this.rememberDetails,
    required this.isCreating,
    required this.onRemember,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name.isEmpty ? 'Her' : name;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      children: [
        const _StepHeading(
          eyebrow: 'Step 07',
          title: 'Review and create',
          subtitle: 'Check everything looks right, then create her.',
        ),
        const SizedBox(height: 18),
        SlideEntrance(
          delay: 140,
          child: Container(
            height: 360,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: SophiaColors.lilac.withValues(alpha: 0.32),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.9),
                  blurRadius: 50,
                  spreadRadius: -22,
                  offset: const Offset(0, 26),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  selectedImageUrl.startsWith('http')
                      ? LoopAnimation(
                          duration: const Duration(seconds: 14),
                          reverse: true,
                          builder: (_, t, child) => Transform.scale(
                            scale: 1.02 + 0.08 * t,
                            child: child,
                          ),
                          child: CachedNetworkImage(
                            imageUrl: selectedImageUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.white.withValues(alpha: 0.05),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.image_not_supported_rounded,
                                color: SophiaColors.muted,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.white.withValues(alpha: 0.05),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image_rounded,
                            color: SophiaColors.muted,
                            size: 32,
                          ),
                        ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 220,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, 0.46, 1],
                          colors: [
                            SophiaColors.panelTop.withValues(alpha: 0),
                            SophiaColors.panelTop.withValues(alpha: 0.55),
                            SophiaColors.panelTop.withValues(alpha: 0.97),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (relationship.isNotEmpty)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: SophiaColors.bgTop.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: SophiaColors.champagne.withValues(
                              alpha: 0.55,
                            ),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.favorite,
                              size: 11,
                              color: SophiaColors.champagne,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              relationship,
                              style: const TextStyle(
                                color: SophiaColors.champagne,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$displayName, $age',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            height: 1.05,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            fontFamily: sophiaSerif,
                          ),
                        ),
                        if (look.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            look,
                            style: const TextStyle(
                              color: SophiaColors.lilac,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        if (vibeTags.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: vibeTags.map((t) => _Tag(t)).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SlideEntrance(
          delay: 220,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: _glass(radius: 22),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.favorite_border_rounded,
                  label: 'Relationship',
                  value: relationship,
                ),
                Divider(
                  height: 1,
                  color: SophiaColors.lilac.withValues(alpha: 0.12),
                ),
                _DetailRow(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Texting style',
                  value: chatStyle,
                ),
                Divider(
                  height: 1,
                  color: SophiaColors.lilac.withValues(alpha: 0.12),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _ToggleRow(
                    label: 'Remember details about you',
                    value: rememberDetails,
                    onChanged: onRemember,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        JumpingButtonWrapper(
          child: AmethystButton(
            label: isCreating ? 'Creating...' : 'Create My Girlfriend',
            onTap: isCreating ? null : onCreate,
            height: 56,
            leading: isCreating
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: ExpressiveLoadingIndicator(color: Colors.white),
                  )
                : const Icon(
                    Icons.favorite_rounded,
                    color: SophiaColors.champagne,
                    size: 18,
                  ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: SophiaColors.champagne, size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(color: SophiaColors.muted, fontSize: 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 13,
              height: 1.25,
            ),
          ),
        ),
        GestureDetector(
          onTap: Haptics.wrap(() => onChanged(!value)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: 46,
            height: 28,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: value ? SophiaColors.amethyst : null,
              color: value ? null : Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: value
                    ? SophiaColors.champagne.withValues(alpha: 0.7)
                    : SophiaColors.lilac.withValues(alpha: 0.25),
              ),
            ),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value
                    ? SophiaColors.champagne
                    : Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
