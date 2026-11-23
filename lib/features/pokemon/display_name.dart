/// An API name tidied for display: `mr-mime` becomes `Mr Mime`.
///
/// Hyphens separate words in the API, so each one becomes a space and each
/// word starts with a capital. It is simple rather than perfect: names that
/// really have a hyphen come out as two words (`ho-oh` gives `Ho Oh`).
String displayName(String apiName) {
  final words = [for (final word in apiName.split('-')) _capitalise(word)];
  return words.join(' ');
}

String _capitalise(String word) {
  if (word.isEmpty) return word;
  return word[0].toUpperCase() + word.substring(1);
}
