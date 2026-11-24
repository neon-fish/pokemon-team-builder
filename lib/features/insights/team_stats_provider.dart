import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokemon_team_builder/domain/team_stats.dart';
import 'package:pokemon_team_builder/features/team/team_members_provider.dart';

/// The team's base stats summed up, or null if there is nobody to sum up (the
/// team is empty, or nobody has loaded). It follows the team by itself.
final teamStatsProvider = Provider<TeamStats?>((ref) {
  final members = ref.watch(teamMembersProvider);
  return members == null ? null : summariseStats(members.loaded);
});
