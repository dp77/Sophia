import 'package:girlfriend/core/haptics.dart';
import 'package:flutter/material.dart';
import 'package:girlfriend/presentation/widget/sophia_toast.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/colors.dart';
import '../view_model/user_provider.dart';

class NameBottomSheet extends StatefulWidget {
  final bool isMandatory;
  final String? initialName;

  const NameBottomSheet({super.key, this.isMandatory = false, this.initialName});

  static Future<void> show(BuildContext context, {bool isMandatory = false, String? initialName}) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !isMandatory,
      enableDrag: !isMandatory,
      backgroundColor: Colors.transparent,
      builder: (context) => PopScope(
        canPop: !isMandatory,
        child: NameBottomSheet(isMandatory: isMandatory, initialName: initialName),
      ),
    );
  }

  @override
  State<NameBottomSheet> createState() => _NameBottomSheetState();
}

class _NameBottomSheetState extends State<NameBottomSheet> {
  late TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName == 'Anonymous' ? '' : widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        border: Border(top: BorderSide(color: white.withValues(alpha: 0.12))),
        boxShadow: [BoxShadow(color: shadow.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, -8))],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.isMandatory ? 'Welcome!' : 'Edit Name',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: white),
                ),
                if (!widget.isMandatory)
                  IconButton(
                    onPressed: Haptics.wrap(() => Navigator.pop(context)),
                    icon: Icon(Icons.close_rounded, color: gray),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.isMandatory ? 'Please enter your name to continue.' : 'Update your display name.',
              style: TextStyle(fontSize: 14, color: gray),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _controller,
              style: TextStyle(color: white, fontSize: 15),
              autofocus: true,
              enabled: !_isLoading,
              cursorColor: extraLightViolet,
              decoration: InputDecoration(
                hintText: 'Enter your name',
                hintStyle: TextStyle(color: gray.withValues(alpha: 0.65)),
                filled: true,
                fillColor: darkPurple.withValues(alpha: 0.65),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: extraLightViolet, width: 1.2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                if (value.trim() == 'Anonymous') {
                  return 'Please use a different name';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: Haptics.wrap(_isLoading
                    ? null
                    : () async {
                        if (_formKey.currentState!.validate()) {
                          setState(() => _isLoading = true);
                          try {
                            final name = _controller.text.trim();
                            final success = await context.read<UserProvider>().updateName(name);
                            if (success) {
                              if (context.mounted) {
                                Navigator.pop(context);
                                await OneSignal.User.addTags({'user_id': name});
                              }
                            } else {
                              SophiaToast.show(msg: 'Failed to update name. Please try again.');
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => _isLoading = false);
                            }
                          }
                        }
                      }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: _isLoading ? null : btnGradient,
                    color: _isLoading ? violet.withValues(alpha: 0.35) : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Continue',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: white),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
