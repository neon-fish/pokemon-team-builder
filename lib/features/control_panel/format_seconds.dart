/// A short way to write a delay: `2 s`, `1.5 s`, `0.25 s`.
///
/// Rounded to a hundredth of a second, with trailing zeros dropped, so whole
/// seconds have no decimal point.
String formatSeconds(Duration duration) {
  final seconds = duration.inMilliseconds / 1000;
  // "2.00" becomes "2" and "1.50" becomes "1.5". The text always has a decimal
  // point, so the zeros dropped are always after it.
  final text = seconds.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return '$text s';
}
