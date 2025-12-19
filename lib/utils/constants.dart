class AppConstants {
  // Firebase paths
  static const String controlPath = 'control';
  static const String sensorsPath = 'sensors';
  static const String notificationsPath = 'notifications';
  static const String cameraPath = 'camera';
  static const String usersPath = 'users';

  // Camera URL
  static const String cameraStreamUrl = 'http://10.83.56.116:5000';

  // Voice commands
  static const List<String> voiceCommands = [
    'bật quạt',
    'tắt quạt',
    'bật đèn phòng khách',
    'tắt đèn phòng khách',
    'bật đèn phòng ngủ',
    'tắt đèn phòng ngủ',
    'bật đèn phòng bếp',
    'tắt đèn phòng bếp',
    'mở cửa',
    'đóng cửa',
    'mở camera',
    'tắt camera',
  ];

  // Device names
  static const String doorDevice = 'Smart Door';
  static const String livingRoomLight = 'Living Room Light';
  static const String bedroomLight = 'Bedroom Light';
  static const String kitchenLight = 'Kitchen Light';
  static const String fanDevice = 'Smart Fan';

  // Sensor thresholds
  static const double temperatureAlertThreshold = 30.0;
  static const int gasAlertThreshold = 50;

  // Audio files
  static const String soundSwitchOn = 'sounds/switch_on.mp3';
  static const String soundSwitchOff = 'sounds/switch_off.mp3';
  static const String soundVoiceStart = 'sounds/voice_start.mp3';
  static const String soundVoiceStop = 'sounds/voice_stop.mp3';
  static const String soundCameraStart = 'sounds/camera_start.mp3';
}

class ImagePaths {
  static const String logo = 'assets/images/logo.png';
  static const String userPlaceholder = 'assets/images/user_placeholder.png';
  static const String cameraPlaceholder =
      'assets/images/camera_placeholder.png';
}

class NotificationTypes {
  static const String doorVoice = 'door_voice';
  static const String gasAlert = 'gas_alert';
  static const String temperatureAlert = 'temperature_alert';
  static const String voice = 'voice';
  static const String voiceAI = 'voice_ai';
  static const String security = 'security';
  static const String device = 'device';
  static const String system = 'system';
}
