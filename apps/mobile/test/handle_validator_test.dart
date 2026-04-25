import 'package:flutter_test/flutter_test.dart';

import 'package:smwhr/shared/utils/handle_validator.dart';

void main() {
  group('HandleValidator.localError', () {
    test('returns null on empty (no premature errors)', () {
      expect(HandleValidator.localError(''), isNull);
      expect(HandleValidator.localError('   '), isNull);
    });

    test('rejects too-short handles', () {
      final err = HandleValidator.localError('ab');
      expect(err, contains('Mínimo 3'));
    });

    test('rejects too-long handles', () {
      final err = HandleValidator.localError('a' * 21);
      expect(err, contains('Máximo 20'));
    });

    test('rejects handles starting with underscore', () {
      final err = HandleValidator.localError('_abc');
      expect(err, contains('letra o número'));
    });

    test('rejects illegal characters', () {
      final err = HandleValidator.localError('hi.there');
      expect(err, contains('Solo letras'));
    });

    test('accepts a clean handle', () {
      expect(HandleValidator.localError('moi_42'), isNull);
      expect(HandleValidator.localError('sofia'), isNull);
    });
  });

  group('HandleValidator.normalize', () {
    test('lowercases and strips leading @', () {
      expect(HandleValidator.normalize('@MOI'), 'moi');
    });
    test('strips inner spaces and trims edges', () {
      expect(HandleValidator.normalize('  m oi  '), 'moi');
    });
    test('idempotent on canonical input', () {
      expect(HandleValidator.normalize('moi_42'), 'moi_42');
    });
  });
}
