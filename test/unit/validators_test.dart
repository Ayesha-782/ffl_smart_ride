import 'package:flutter_test/flutter_test.dart';
import 'package:ffl_smart_ride/core/utils/validators.dart';

void main() {
  group('Validators Test Suite', () {
    test('Full Name validation', () {
      expect(Validators.validateFullName(''), isNotNull);
      expect(Validators.validateFullName('A'), isNotNull);
      expect(Validators.validateFullName('Zain Malik'), isNull);
    });

    test('Employee ID validation', () {
      expect(Validators.validateEmployeeId(''), isNotNull);
      expect(Validators.validateEmployeeId('12'), isNotNull);
      expect(Validators.validateEmployeeId('FFL-1092'), isNull);
    });

    test('Email validation', () {
      expect(Validators.validateEmail('invalid-email'), isNotNull);
      expect(Validators.validateEmail('user@'), isNotNull);
      expect(Validators.validateEmail('user@ffl'), isNotNull);
      expect(Validators.validateEmail('employee@ffl.com'), isNull);
    });

    test('Password validation', () {
      expect(Validators.validatePassword('123'), isNotNull);
      expect(Validators.validatePassword('secret123'), isNull);
    });

    test('Confirm Password validation', () {
      expect(Validators.validateConfirmPassword('pass123', 'pass456'), isNotNull);
      expect(Validators.validateConfirmPassword('pass123', 'pass123'), isNull);
    });

    test('License Plate validation', () {
      expect(Validators.validateLicensePlate(''), isNotNull);
      expect(Validators.validateLicensePlate('LEA-2024'), isNull);
      expect(Validators.validateLicensePlate('ABC 123'), isNull);
      expect(Validators.validateLicensePlate('', isRequired: false), isNull);
    });
  });
}
