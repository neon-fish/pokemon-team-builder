/// The short text for a damage multiplier in a coverage cell: `4×`, `2×`, `½`,
/// `¼` or `0`. Normal damage (1) has no label, so the cells that matter stand
/// out. Any other value (not expected) is shown as it is.
String multiplierLabel(double multiplier) => switch (multiplier) {
  4.0 => '4×',
  2.0 => '2×',
  1.0 => '',
  0.5 => '½',
  0.25 => '¼',
  0.0 => '0',
  _ => '$multiplier×',
};
