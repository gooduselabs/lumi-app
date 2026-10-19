import 'package:flutter/material.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';

typedef ReportSubmit = Future<void> Function(String reason, String? details);

Future<void> showReportSheet(BuildContext context, ReportSubmit onSubmit) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(onSubmit: onSubmit),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.onSubmit});
  final ReportSubmit onSubmit;
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;
  final _details = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await widget.onSubmit(_reason!, _details.text.trim());
      if (!mounted) return;
      final l = context.l10n;
      Navigator.pop(context);
      showSnack(context, l.reportSent);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, context.l10n.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reasons = {
      'SPAM': l.reasonSpam,
      'HARASSMENT': l.reasonHarassment,
      'INAPPROPRIATE': l.reasonInappropriate,
      'UNDERAGE': l.reasonUnderage,
      'SCAM': l.reasonScam,
      'OTHER': l.reasonOther,
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.reportTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(l.reportReason, style: const TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in reasons.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: _reason == e.key,
              onSelected: (_) => setState(() => _reason = e.key),
            ),
        ]),
        const SizedBox(height: 16),
        TextField(controller: _details, maxLength: 500, maxLines: 3, decoration: InputDecoration(hintText: l.reportDetails)),
        const SizedBox(height: 8),
        GradientButton(label: l.submit, loading: _sending, onPressed: _reason == null ? null : _submit, gradient: AppColors.warmGradient),
      ]),
    );
  }
}
