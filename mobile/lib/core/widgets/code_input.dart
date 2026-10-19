import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// 6-box OTP input backed by a single hidden TextField (paste & autofill friendly).
class CodeInput extends StatefulWidget {
  const CodeInput({super.key, required this.controller, this.onCompleted, this.length = 6, this.hasError = false});
  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final int length;
  final bool hasError;

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _changed() {
    setState(() {});
    if (widget.controller.text.length == widget.length) widget.onCompleted?.call(widget.controller.text);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(children: [
        Opacity(
          opacity: 0,
          child: SizedBox(
            height: 60,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(widget.length)],
              showCursor: false,
            ),
          ),
        ),
        IgnorePointer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.length, (i) {
              final filled = i < text.length;
              final active = i == text.length && _focus.hasFocus;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 48,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    width: active || filled ? 1.8 : 1.2,
                    color: widget.hasError ? AppColors.danger : active ? AppColors.pink : filled ? AppColors.violet : AppColors.stroke,
                  ),
                ),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 160),
                  scale: filled ? 1 : 0.4,
                  child: Text(filled ? text[i] : '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }
}
