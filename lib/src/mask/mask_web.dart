import 'dart:math';

int clearLeastSignificantBytes(int value, int bytes) {
  final b = pow(2, 4 * bytes).toInt();
  return value ~/ b * b;
}
