import 'package:material_ui/material_ui.dart';

/// Says that [missingCount] team members are not included in what is shown.
///
/// Said out loud on every view of the team: one that looks safe, or strong,
/// may just be missing a member.
class IncompleteWarning extends StatelessWidget {
  const IncompleteWarning(this.missingCount, {super.key});

  final int missingCount;

  @override
  Widget build(BuildContext context) {
    final colours = Theme.of(context).colorScheme;
    final who = missingCount == 1
        ? '1 team member is'
        : '$missingCount team members are';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colours.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: colours.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$who still loading or could not be loaded, so this may be '
                  'incomplete.',
                  style: TextStyle(color: colours.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
