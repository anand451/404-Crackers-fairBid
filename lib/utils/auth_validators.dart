class AuthValidators {
  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(input)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? fullName(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      return 'Full name is required';
    }
    if (input.length < 3) {
      return 'Enter your full name';
    }
    return null;
  }

  static String? phone(String? value) {
    final digits = _digitsOnly(value);
    if (digits.isEmpty) {
      return 'Phone number is required';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(digits)) {
      return 'Phone number must be 10 digits';
    }
    return null;
  }

  static String? aadhaar(String? value) {
    final digits = _digitsOnly(value);
    if (digits.isEmpty) {
      return 'Aadhaar number is required';
    }
    if (!RegExp(r'^\d{12}$').hasMatch(digits)) {
      return 'Aadhaar number must be 12 digits';
    }
    return null;
  }

  static String? pan(String? value) {
    final input = value?.trim().toUpperCase() ?? '';
    if (input.isEmpty) {
      return 'PAN number is required';
    }
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(input)) {
      return 'Use PAN format like ABCDE1234F';
    }
    return null;
  }

  static String? password(String? value) {
    final input = value ?? '';
    if (input.isEmpty) {
      return 'Password is required';
    }
    if (input.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{6,}$').hasMatch(input)) {
      return 'Use at least one letter and one number';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if ((value ?? '').isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? dateOfBirth(DateTime? value) {
    if (value == null) {
      return 'Date of birth is required';
    }
    final today = DateTime.now();
    final age = today.year -
        value.year -
        ((today.month < value.month ||
                (today.month == value.month && today.day < value.day))
            ? 1
            : 0);
    if (age < 18) {
      return 'You must be at least 18 years old';
    }
    return null;
  }

  static String _digitsOnly(String? value) {
    return (value ?? '').replaceAll(RegExp(r'\D'), '');
  }
}
