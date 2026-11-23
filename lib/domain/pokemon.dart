import 'package:pokemon_team_builder/domain/pokemon_type.dart';

/// The six base stats, in the order they are usually shown.
enum Stat { hp, attack, defense, specialAttack, specialDefense, speed }

/// A Pokémon's six base stats.
class BaseStats {
  const BaseStats({
    required this.hp,
    required this.attack,
    required this.defense,
    required this.specialAttack,
    required this.specialDefense,
    required this.speed,
  });

  final int hp;
  final int attack;
  final int defense;
  final int specialAttack;
  final int specialDefense;
  final int speed;

  /// The value of one stat, so a screen can go through [Stat.values] instead
  /// of naming each field.
  int valueOf(Stat stat) => switch (stat) {
    Stat.hp => hp,
    Stat.attack => attack,
    Stat.defense => defense,
    Stat.specialAttack => specialAttack,
    Stat.specialDefense => specialDefense,
    Stat.speed => speed,
  };

  /// All six added together: a rough measure of overall strength.
  int get total => Stat.values.fold(0, (sum, stat) => sum + valueOf(stat));
}

/// A Pokémon (or one of its alternative forms) as the app uses it.
class Pokemon {
  const Pokemon({
    required this.id,
    required this.name,
    required this.types,
    required this.stats,
    this.spriteUrl,
  });

  final int id;

  /// The API's name, such as `mr-mime`. Tidying it for display is the UI's job.
  final String name;

  /// One or two types, primary type first.
  final List<PokemonType> types;

  final BaseStats stats;

  /// A picture to show, or null if the API has none for this Pokémon.
  final String? spriteUrl;
}
