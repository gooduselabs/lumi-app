import 'package:flutter/material.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';

/// Min/max age slider (18–99). [onChangeEnd] fires once the user lets go.
class AgeRangeField extends StatefulWidget {
  const AgeRangeField({super.key, required this.min, required this.max, required this.onChangeEnd, this.hint});
  final int min;
  final int max;
  final void Function(int min, int max) onChangeEnd;
  final String? hint;

  @override
  State<AgeRangeField> createState() => _AgeRangeFieldState();
}

class _AgeRangeFieldState extends State<AgeRangeField> {
  late RangeValues _v = RangeValues(widget.min.toDouble(), widget.max.toDouble());

  @override
  void didUpdateWidget(AgeRangeField old) {
    super.didUpdateWidget(old);
    if (old.min != widget.min || old.max != widget.max) _v = RangeValues(widget.min.toDouble(), widget.max.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(l.ageRange, style: const TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(
          l.ageRangeValue(_v.start.round(), _v.end.round()),
          key: const Key('ageRangeValue'),
          style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w700),
        ),
      ]),
      RangeSlider(
        values: _v,
        min: 18,
        max: 99,
        divisions: 81,
        labels: RangeLabels('${_v.start.round()}', '${_v.end.round()}'),
        onChanged: (v) => setState(() => _v = v),
        onChangeEnd: (v) => widget.onChangeEnd(v.start.round(), v.end.round()),
      ),
      if (widget.hint != null) Text(widget.hint!, style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
    ]);
  }
}

class GenderChips extends StatelessWidget {
  const GenderChips({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Wrap(spacing: 8, children: [
      for (final (v, label) in [('ANY', l.filterAny), ('FEMALE', l.genderFemale), ('MALE', l.genderMale)])
        ChoiceChip(label: Text(label), selected: value == v, onSelected: (_) => onChanged(v)),
    ]);
  }
}

/// Localized feedback for a failed location request (with a Settings shortcut when blocked).
void showLocationError(BuildContext context, Object e, LocationService svc) {
  final l = context.l10n;
  if (e is! LocationFailure) {
    showSnack(context, l.errorText(e), error: true);
    return;
  }
  final text = switch (e.issue) {
    LocationIssue.serviceOff => l.locationServiceOff,
    LocationIssue.denied => l.locationDenied,
    LocationIssue.deniedForever => l.locationDeniedForever,
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text),
    backgroundColor: AppColors.danger,
    action: e.issue == LocationIssue.denied ? null : SnackBarAction(label: l.openSettings, onPressed: svc.openSettings),
  ));
}
