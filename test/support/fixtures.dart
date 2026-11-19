import 'dart:convert';
import 'dart:io';

/// Loads and decodes `test/fixtures/[name]`.
///
/// Fixtures are trimmed copies of real API responses. `flutter test` runs from
/// the project root, so the relative path works.
Object? loadFixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync());
