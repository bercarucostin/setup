import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a "Typewriter" time picker dialog (HH : MM with editable chips).
/// - Tap a chip to type (mobile-friendly numeric keyboard)
/// - Auto-clamps to 00..23 and 00..59
/// - Auto-advances from hour -> minute after 2 digits
/// - Arrow up/down works on hardware keyboards (nice for desktop)
Future<TimeOfDay?> showTypewriterTimePickerDialog(
  BuildContext context, {
  required String title,
  required TimeOfDay initial,
  String hintText = 'Tap and type',
  bool barrierDismissible = true,
}) async {
  return showDialog<TimeOfDay?>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => _TypewriterTimePickerDialog(
      title: title,
      initial: initial,
      hintText: hintText,
    ),
  );
}

class _TypewriterTimePickerDialog extends StatefulWidget {
  final String title;
  final TimeOfDay initial;
  final String hintText;

  const _TypewriterTimePickerDialog({
    required this.title,
    required this.initial,
    required this.hintText,
  });

  @override
  State<_TypewriterTimePickerDialog> createState() =>
      _TypewriterTimePickerDialogState();
}

class _TypewriterTimePickerDialogState
    extends State<_TypewriterTimePickerDialog> {
  static const Color _bg = Colors.white;
  static const Color _chipBg = Color(0xFFF2F3F7);
  static const Color _okPurple = Color.fromARGB(255, 25, 29, 151);
  static const Color _muted = Color(0xFF6F7583);
  static const Color _text = Color(0xFF1A1B22);

  late final TextEditingController _hourCtrl;
  late final TextEditingController _minCtrl;

  final FocusNode _hourFocus = FocusNode(debugLabel: 'hour');
  final FocusNode _minFocus = FocusNode(debugLabel: 'minute');

  int _hour = 0;
  int _minute = 0;

  @override
  void initState() {
    super.initState();
    _hour = widget.initial.hour.clamp(0, 23);
    _minute = widget.initial.minute.clamp(0, 59);

    _hourCtrl = TextEditingController(text: _two(_hour));
    _minCtrl = TextEditingController(text: _two(_minute));

    // Start on hours (like typical pickers)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusAndSelect(_hourFocus, _hourCtrl);
    });
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    _hourFocus.dispose();
    _minFocus.dispose();
    super.dispose();
  }

  void _focusAndSelect(FocusNode node, TextEditingController ctrl) {
    node.requestFocus();
    ctrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: ctrl.text.length,
    );
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  int _parseDigits(String s) =>
      int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  void _setHourFromText(String raw) {
    final v = _parseDigits(raw).clamp(0, 23);
    _hour = v;
    // keep typed text as-is while editing; we normalize on blur/commit
    setState(() {});
  }

  void _setMinFromText(String raw) {
    final v = _parseDigits(raw).clamp(0, 59);
    _minute = v;
    setState(() {});
  }

  void _normalizeControllers() {
    _hourCtrl.text = _two(_hour);
    _minCtrl.text = _two(_minute);
  }

  void _incActive(int delta) {
    if (_hourFocus.hasFocus) {
      _hour = (_hour + delta) % 24;
      if (_hour < 0) _hour += 24;
    } else if (_minFocus.hasFocus) {
      _minute = (_minute + delta) % 60;
      if (_minute < 0) _minute += 60;
    }
    _normalizeControllers();
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _incActive(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _incActive(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _focusAndSelect(_hourFocus, _hourCtrl);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _focusAndSelect(_minFocus, _minCtrl);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _onOk() {
    _normalizeControllers();
    Navigator.pop(context, TimeOfDay(hour: _hour, minute: _minute));
  }

  @override
  Widget build(BuildContext context) {
    final isHourFocused = _hourFocus.hasFocus;
    final isMinFocused = _minFocus.hasFocus;

    return Dialog(
      backgroundColor: _bg,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.8,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TimeChipField(
                    controller: _hourCtrl,
                    focusNode: _hourFocus,
                    focused: isHourFocused,
                    chipBg: _chipBg,
                    textColor: _text,
                    accent: _okPurple,
                    onTap: () => _focusAndSelect(_hourFocus, _hourCtrl),
                    onChanged: (v) {
                      _setHourFromText(v);

                      // If user typed 2 digits, auto-move to minutes (mobile friendly)
                      final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                      if (digits.length >= 2) {
                        _normalizeControllers();
                        _focusAndSelect(_minFocus, _minCtrl);
                      }
                    },
                    onEditingComplete: () {
                      _normalizeControllers();
                      _focusAndSelect(_minFocus, _minCtrl);
                    },
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    ':',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  _TimeChipField(
                    controller: _minCtrl,
                    focusNode: _minFocus,
                    focused: isMinFocused,
                    chipBg: _chipBg,
                    textColor: _text,
                    accent: _okPurple,
                    onTap: () => _focusAndSelect(_minFocus, _minCtrl),
                    onChanged: (v) => _setMinFromText(v),
                    onEditingComplete: () {
                      _normalizeControllers();
                      _minFocus.unfocus();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Text(
                widget.hintText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),

              const SizedBox(height: 18),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: TextButton.styleFrom(
                      foregroundColor: _muted,
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 160,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _onOk,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _okPurple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeChipField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;

  final Color chipBg;
  final Color textColor;
  final Color accent;

  final VoidCallback onTap;
  final ValueChanged<String> onChanged;
  final VoidCallback onEditingComplete;

  const _TimeChipField({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.chipBg,
    required this.textColor,
    required this.accent,
    required this.onTap,
    required this.onChanged,
    required this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = focused ? accent : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        width: 118,
        height: 104,
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: 2),
        ),
        alignment: Alignment.center,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 2,
          style: TextStyle(
            fontSize: 60,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: textColor,
            height: 1.0,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: onChanged,
          onEditingComplete: onEditingComplete,
        ),
      ),
    );
  }
}
