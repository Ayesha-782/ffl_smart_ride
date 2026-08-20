class Validators {
  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final RegExp _licensePlateRegExp = RegExp(
    r'^[A-Z0-9\-\s]{3,12}$',
    caseSensitive: false,
  );

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  static String? validateEmployeeId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your Employee / National ID';
    }
    if (value.trim().length < 3) {
      return 'Employee ID must be at least 3 characters';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address';
    }
    if (!_emailRegExp.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter phone number';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 13) {
      return 'Enter valid mobile number (e.g. 0300-1234567)';
    }
    return null;
  }

  static String? validateCnic(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'National ID / CNIC is required';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 13) {
      return 'CNIC must be 13 digits (e.g. 35201-1234567-1)';
    }
    return null;
  }

  static String? validateLicensePlate(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Please enter your vehicle license plate' : null;
    }
    if (!_licensePlateRegExp.hasMatch(value.trim())) {
      return 'Invalid vehicle number (e.g. ABC-1234 or LEA-21-505)';
    }
    return null;
  }
}
