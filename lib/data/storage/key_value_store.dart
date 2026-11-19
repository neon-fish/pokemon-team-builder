/// Somewhere small pieces of text can be saved and read back, even after the
/// app is closed.
///
/// The app depends on this interface, not on a particular storage mechanism:
/// on the web the real implementation is the browser's `localStorage`, and
/// tests use an in-memory one. Implementations may throw if the storage is
/// unavailable; callers that can carry on without it should catch.
abstract interface class KeyValueStore {
  /// The text saved under [key], or null if there is none.
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}
