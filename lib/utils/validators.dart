class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập email của bạn';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Vui lòng nhập email hợp lệ';
    }

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu của bạn';
    }

    if (value.length < 6) {
      return 'Mật khẩu phải có ít nhất 6 ký tự';
    }

    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập tên của bạn';
    }

    if (value.length < 2) {
      return 'Tên phải có ít nhất 2 ký tự';
    }

    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập số điện thoại của bạn';
    }

    final phoneRegex = RegExp(r'^[0-9]{10,11}$');

    if (!phoneRegex.hasMatch(value)) {
      return 'Vui lòng nhập số điện thoại hợp lệ';
    }

    return null;
  }

  static String? validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập địa chỉ của bạn';
    }

    if (value.length < 5) {
      return 'Địa chỉ phải có ít nhất 5 ký tự';
    }

    return null;
  }

  static String? validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập $fieldName';
    }

    return null;
  }

  static String? validateTemperature(double? value) {
    if (value == null) return null;

    if (value < -50 || value > 100) {
      return 'Nhiệt độ không hợp lệ';
    }

    return null;
  }

  static String? validateHumidity(double? value) {
    if (value == null) return null;

    if (value < 0 || value > 100) {
      return 'Độ ẩm không hợp lệ';
    }

    return null;
  }
}
