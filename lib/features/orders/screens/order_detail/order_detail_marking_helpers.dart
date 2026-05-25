part of '../order_detail_screen.dart';

Map<String, List<String>> _copyMarkingCodes(
  Map<String, List<String>> markingCodes,
) {
  if (markingCodes.isEmpty) return {};
  return markingCodes.map(
    (key, codes) => MapEntry(key, List<String>.unmodifiable(codes)),
  );
}

Map<String, int> _countsFromMarkingCodes(
  Map<String, List<String>> markingCodes,
) {
  if (markingCodes.isEmpty) return {};
  return markingCodes.map((key, codes) => MapEntry(key, codes.length));
}
