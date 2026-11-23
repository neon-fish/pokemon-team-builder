import 'package:pokemon_team_builder/domain/pokemon.dart';

/// The name of a stat in full, for the bars.
String statName(Stat stat) => switch (stat) {
  Stat.hp => 'HP',
  Stat.attack => 'Attack',
  Stat.defense => 'Defence',
  Stat.specialAttack => 'Sp. attack',
  Stat.specialDefense => 'Sp. defence',
  Stat.speed => 'Speed',
};

/// A short name for a stat, for where there is little room (the radar chart).
String statAbbreviation(Stat stat) => switch (stat) {
  Stat.hp => 'HP',
  Stat.attack => 'Atk',
  Stat.defense => 'Def',
  Stat.specialAttack => 'SpA',
  Stat.specialDefense => 'SpD',
  Stat.speed => 'Spe',
};
