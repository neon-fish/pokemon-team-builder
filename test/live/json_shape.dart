/// Compares the shape of a saved response with a live one.
///
/// The saved fixtures are trimmed copies, so the question is not "are they
/// equal" but "does the live response still have everything the fixture has,
/// as the same kind of value?". Returns one line for each difference, or an
/// empty list if the live response still matches.
///
/// - Objects: every key in [saved] must be in [live], and match by the same
///   rules. Keys only in [live] are fine (the fixtures are trimmed).
/// - Lists: the first item of each is compared, since the items of one list
///   share a shape. An empty list on either side says nothing, so it is fine.
/// - A null on either side is fine: the API leaves optional fields null.
/// - Anything else must be the same kind of value (string, number or
///   boolean). The values themselves are not compared; stats can change.
List<String> shapeDifferences(Object? saved, Object? live, [String path = '']) {
  if (saved == null || live == null) return [];

  if (saved is Map<String, Object?>) {
    if (live is! Map<String, Object?>) {
      return ['$path: was an object, is now ${_kind(live)}'];
    }
    return [
      for (final key in saved.keys)
        if (!live.containsKey(key))
          '$path.$key: missing'
        else
          ...shapeDifferences(saved[key], live[key], '$path.$key'),
    ];
  }

  if (saved is List<Object?>) {
    if (live is! List<Object?>) {
      return ['$path: was a list, is now ${_kind(live)}'];
    }
    if (saved.isEmpty || live.isEmpty) return [];
    return shapeDifferences(saved.first, live.first, '$path[0]');
  }

  return _kind(saved) == _kind(live)
      ? []
      : ['$path: was ${_kind(saved)}, is now ${_kind(live)}'];
}

String _kind(Object? value) => switch (value) {
  null => 'null',
  Map() => 'an object',
  List() => 'a list',
  String() => 'a string',
  num() => 'a number',
  bool() => 'a boolean',
  _ => 'something else',
};
