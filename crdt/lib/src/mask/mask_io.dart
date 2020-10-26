int clearLeastSignificantBytes(int value, int bytes) {
  final b = 4 * bytes;
  return value >> b << b;
}
