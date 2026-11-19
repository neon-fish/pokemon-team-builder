// Small helpers for reading decoded JSON safely.
//
// `jsonDecode` hands back `Object?`, so nothing about its shape is known. Each
// helper checks one expectation and throws a [FormatException] saying what was
// wrong. Repositories catch that single exception type at their boundary and
// turn it into a `MalformedResponseFailure`, so it never reaches the UI.

/// [json] as an object (a map with string keys).
Map<String, Object?> asJsonObject(Object? json, String what) {
  if (json is Map<String, Object?>) return json;
  throw FormatException('Expected $what to be an object');
}

/// [json] as a list.
List<Object?> asJsonList(Object? json, String what) {
  if (json is List<Object?>) return json;
  throw FormatException('Expected $what to be a list');
}

/// [json] as a string.
String asJsonString(Object? json, String what) {
  if (json is String) return json;
  throw FormatException('Expected $what to be a string');
}
