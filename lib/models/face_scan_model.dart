class FaceImageData {
  String base64;
  DateTime timestamp;
  int size;
  String angle;

  FaceImageData({
    required this.base64,
    required this.timestamp,
    required this.size,
    required this.angle,
  });

  factory FaceImageData.fromMap(Map<String, dynamic> map) {
    return FaceImageData(
      base64: map['base64'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      size: map['size'] ?? 0,
      angle: map['angle'] ?? 'trước',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'base64': base64,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'size': size,
      'angle': angle,
    };
  }
}

class FaceScanModel {
  String userId;
  bool faceRegistered;
  DateTime faceRegistrationDate;
  Map<String, FaceImageData> faceImages;
  int totalFaceImages;
  int targetImages;
  DateTime lastFaceUpdate;
  bool registrationComplete;
  String registrationMethod;

  FaceScanModel({
    required this.userId,
    required this.faceRegistered,
    required this.faceRegistrationDate,
    required this.faceImages,
    required this.totalFaceImages,
    required this.targetImages,
    required this.lastFaceUpdate,
    required this.registrationComplete,
    required this.registrationMethod,
  });

  factory FaceScanModel.fromMap(Map<String, dynamic> map, String userId) {
    Map<String, FaceImageData> images = {};
    if (map['faceImages'] != null) {
      Map<String, dynamic> imageMap =
          Map<String, dynamic>.from(map['faceImages']);
      imageMap.forEach((key, value) {
        images[key] = FaceImageData.fromMap(Map<String, dynamic>.from(value));
      });
    }

    return FaceScanModel(
      userId: userId,
      faceRegistered: map['faceRegistered'] ?? false,
      faceRegistrationDate: DateTime.fromMillisecondsSinceEpoch(
        map['faceRegistrationDate'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      faceImages: images,
      totalFaceImages: map['totalFaceImages'] ?? 0,
      targetImages: map['targetImages'] ?? 60,
      lastFaceUpdate: DateTime.fromMillisecondsSinceEpoch(
        map['lastFaceUpdate'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      registrationComplete: map['registrationComplete'] ?? false,
      registrationMethod: map['registrationMethod'] ?? 'continuous_capture',
    );
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> images = {};
    faceImages.forEach((key, value) {
      images[key] = value.toMap();
    });

    return {
      'faceRegistered': faceRegistered,
      'faceRegistrationDate': faceRegistrationDate.millisecondsSinceEpoch,
      'faceImages': images,
      'totalFaceImages': totalFaceImages,
      'targetImages': targetImages,
      'lastFaceUpdate': lastFaceUpdate.millisecondsSinceEpoch,
      'registrationComplete': registrationComplete,
      'registrationMethod': registrationMethod,
    };
  }
}
