class UserModel {
  String id;
  String name;
  String email;
  String? phone;
  String? address;
  DateTime createdAt;
  DateTime updatedAt;
  bool? faceRegistered;
  DateTime? faceRegistrationDate;
  int? totalFaceImages;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.address,
    required this.createdAt,
    required this.updatedAt,
    this.faceRegistered,
    this.faceRegistrationDate,
    this.totalFaceImages,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? 'Người dùng',
      email: map['email'] ?? '',
      phone: map['phone'],
      address: map['address'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updatedAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      faceRegistered: map['faceRegistered'] ?? false,
      faceRegistrationDate: map['faceRegistrationDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['faceRegistrationDate'])
          : null,
      totalFaceImages: map['totalFaceImages'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'faceRegistered': faceRegistered,
      'faceRegistrationDate': faceRegistrationDate?.millisecondsSinceEpoch,
      'totalFaceImages': totalFaceImages,
    };
  }
}
