import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('source files do not contain common Cyrillic mojibake', () {
    final badFragments = <String>[
      '\u0432\u201a\u0405', // ruble sign decoded as CP1251 mojibake.
      '\u0420\u045f',
      '\u0420\u045c',
      '\u0420\u0459',
      '\u0420\u0458',
      '\u0420\u0406',
      '\u0420\u0402',
      '\u0420\u0453',
      '\u0420\u0455',
      '\u0420\u2019',
      '\u0420\u00b0',
      '\u0420\u00b1',
      '\u0420\u00b5',
      '\u0420\u00b8',
      '\u0420\u00bb',
      '\u0420\u00bd',
      '\u0420\u00be',
      '\u0421\u0403',
      '\u0421\u040b',
      '\u0421\u201a',
      '\u0421\u2019',
      '\u0421\u2039',
    ];
    final roots = <String>['lib', 'test'];
    final extensions = <String>{'.dart'};
    final offenders = <String>[];

    for (final root in roots) {
      final directory = Directory(root);
      if (!directory.existsSync()) {
        continue;
      }

      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !extensions.any(entity.path.endsWith)) {
          continue;
        }

        final content = entity.readAsStringSync();
        for (final fragment in badFragments) {
          if (content.contains(fragment)) {
            offenders.add('${entity.path}: contains "$fragment"');
          }
        }
      }
    }

    expect(offenders, isEmpty);
  });
}
