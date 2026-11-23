import 'package:pokemon_team_builder/domain/team_analysis.dart';
import 'package:pokemon_team_builder/features/pokemon/display_name.dart';

/// A sentence saying why the team is exposed to a type, such as "3 of 6 are
/// weak to Ground and nobody resists it." Null if the team is not exposed.
///
/// The counts are of the members that were analysed, so "of 6" is a team of
/// six, and "of 2" is a team of two with empty slots.
String? describeExposure(TypeMatchup matchup) {
  if (!matchup.isExposed) return null;

  final weak = matchup.weakCount;
  final of = matchup.knownCount;
  final type = displayName(matchup.attacking.name);
  final covered = matchup.resistantCount + matchup.immuneCount;

  final subject = '$weak of $of ${weak == 1 ? 'is' : 'are'} weak to $type';
  if (covered == 0) return '$subject and nobody resists it.';

  final verbs = covered == 1 ? 'resists or ignores' : 'resist or ignore';
  return '$subject, but only $covered $verbs it.';
}
