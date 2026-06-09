/// Normalizes text for search: lowercase, strips Greek accents,
/// converts final sigma to sigma. Makes LIKE queries accent- and
/// case-insensitive for Greek (SQLite LIKE only handles ASCII case).
String normalizeForSearch(String input) {
  const map = {
    '\u03ac': '\u03b1', // accented alpha
    '\u03ad': '\u03b5', // accented epsilon
    '\u03ae': '\u03b7', // accented eta
    '\u03af': '\u03b9', // accented iota
    '\u03cc': '\u03bf', // accented omicron
    '\u03cd': '\u03c5', // accented upsilon
    '\u03ce': '\u03c9', // accented omega
    '\u03ca': '\u03b9', // iota dialytika
    '\u03cb': '\u03c5', // upsilon dialytika
    '\u0390': '\u03b9', // iota dialytika tonos
    '\u03b0': '\u03c5', // upsilon dialytika tonos
    '\u03c2': '\u03c3', // final sigma -> sigma
  };
  var out = input.toLowerCase();
  map.forEach((k, v) => out = out.replaceAll(k, v));
  return out;
}