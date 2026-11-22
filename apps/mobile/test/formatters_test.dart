import 'package:ballal/core/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeGuineaPhone', () {
    test('numéro local guinéen', () {
      expect(normalizeGuineaPhone('620 00 00 00'), '+224620000000');
      expect(normalizeGuineaPhone('626449971'), '+224626449971');
    });
    test('formats internationaux', () {
      expect(normalizeGuineaPhone('+224 620 00 00 00'), '+224620000000');
      expect(normalizeGuineaPhone('00224620000000'), '+224620000000');
      expect(normalizeGuineaPhone('224620000000'), '+224620000000');
    });
    test('numéros invalides refusés', () {
      expect(normalizeGuineaPhone(''), isNull);
      expect(normalizeGuineaPhone('12'), isNull);
      expect(normalizeGuineaPhone('920000000'), isNull); // ne commence pas par 6 ou 3
      expect(normalizeGuineaPhone('62000000'), isNull); // 8 chiffres
    });
    test('autres pays acceptés', () {
      expect(normalizeGuineaPhone('+221771234567'), '+221771234567');
    });
  });

  test('formatPriceRange', () {
    expect(formatPriceRange(null, null, null), '');
    expect(formatPriceRange(50000, null, null), contains('GNF'));
    expect(formatPriceRange(50000, 100000, 'par intervention'), contains('par intervention'));
  });

  test('normalizeEmail', () {
    expect(normalizeEmail('  Amadou@Gmail.com '), 'amadou@gmail.com');
    expect(normalizeEmail('amadou@gmail'), isNull);
    expect(normalizeEmail('pas un email'), isNull);
  });
}
