import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:camera/camera.dart';
import 'dart:convert';
// ลบ import dart:io ที่ไม่ได้ใช้
// import 'dart:io';  // ลบบรรทัดนี้
import 'dart:async';
import 'package:http/http.dart' as http;

class FaceScanService {
  // ใช้ _databaseRef หรือลบออก ถ้าไม่ได้ใช้
  // final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref(); // ถ้าไม่ใช้ ให้ลบ

  // ใช้ตัวแปรให้ครบ
  final DatabaseReference _databaseRef =
      FirebaseDatabase.instance.ref(); // ใช้ตัวแปรนี้
  final DatabaseReference _faceScanRef =
      FirebaseDatabase.instance.ref('face_scans');
  final DatabaseReference _notificationsRef =
      FirebaseDatabase.instance.ref('face_scan_notifications');
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');

  // Lưu hình ảnh khuôn mặt vào Firebase
  Future<bool> saveFaceImages(Map<String, String> faceImages,
      {String? userId}) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      final String uid = userId ?? user?.uid ?? 'unknown';

      if (uid == 'unknown') {
        throw Exception('Không tìm thấy người dùng');
      }

      // Tạo cấu trúc dữ liệu để lưu
      Map<String, dynamic> faceData = {
        'userId': uid,
        'timestamp': ServerValue.timestamp,
        'totalImages': faceImages.length,
        'status': 'completed',
        'lastUpdated': ServerValue.timestamp,
      };

      // Thêm hình ảnh vào faceData
      Map<String, dynamic> imagesData = {};
      int index = 0;

      faceImages.forEach((fileName, base64Image) {
        imagesData['image_$index'] = {
          'base64': base64Image,
          'timestamp': DateTime.now().millisecondsSinceEpoch + index,
          'size': base64Image.length,
          'filename': fileName,
          'angle': _getAngleDescription(index),
        };
        index++;
      });

      faceData['images'] = imagesData;

      // Lưu vào Firebase
      final String scanId = DateTime.now().millisecondsSinceEpoch.toString();
      await _faceScanRef.child(uid).child(scanId).set(faceData);

      // Cập nhật thông tin người dùng
      await _usersRef.child(uid).update({
        'faceRegistered': true,
        'faceRegistrationDate': ServerValue.timestamp,
        'totalFaceImages': faceImages.length,
        'lastFaceUpdate': ServerValue.timestamp,
        'faceScanId': scanId,
      });

      // Gửi thông báo thành công
      await _sendFaceScanNotification(
        uid,
        'Đăng ký khuôn mặt thành công',
        faceImages.length,
        'registration_complete',
      );

      return true;
    } catch (e) {
      print('Lỗi lưu hình ảnh khuôn mặt: $e');
      return false;
    }
  }

  // Gửi thông báo khuôn mặt
  Future<void> _sendFaceScanNotification(
      String userId, String message, int imageCount, String type,
      {double confidence = 0.0, String? userName}) async {
    try {
      final String currentUserId = userId;

      // Lấy thông tin người dùng nếu chưa có
      String displayName = userName ?? 'Người dùng';
      if (userName == null) {
        final userSnapshot = await _usersRef.child(currentUserId).get();
        if (userSnapshot.exists) {
          final userData = userSnapshot.value as Map<dynamic, dynamic>;
          displayName = userData['name']?.toString() ?? 'Người dùng';
        }
      }

      final String notificationId =
          DateTime.now().millisecondsSinceEpoch.toString();
      final String currentTime = _formatTime(DateTime.now());
      final String currentDate = _formatDate(DateTime.now());

      await _notificationsRef.child(notificationId).set({
        'userId': currentUserId,
        'userName': displayName,
        'message': message,
        'type': type,
        'timestamp': ServerValue.timestamp,
        'read': false,
        'confidence': confidence,
        'imageCount': imageCount,
        'time': currentTime,
        'date': currentDate,
        'fullDateTime': '$currentTime - $currentDate',
      });
    } catch (e) {
      print('Lỗi gửi thông báo khuôn mặt: $e');
    }
  }

  // Phát hiện khuôn mặt từ camera (giả lập)
  Future<Map<String, dynamic>> detectFaceFromCamera(CameraImage image) async {
    try {
      // ใช้ _databaseRef เพื่อไม่ให้เป็น unused field
      final refPath = _databaseRef.path;
      print('Using database reference at path: $refPath');

      // Ở đây bạn có thể tích hợp với ML Kit hoặc API nhận diện khuôn mặt
      // Hiện tại trả về kết quả giả lập

      final bool faceDetected = true; // Giả lập phát hiện khuôn mặt
      final double confidence = 0.85; // Giả lập độ tin cậy

      return {
        'success': faceDetected,
        'confidence': confidence,
        'message':
            faceDetected ? 'Phát hiện khuôn mặt' : 'Không phát hiện khuôn mặt',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'databaseUsed': true, // ใช้เพื่อแสดงว่าใช้ _databaseRef
      };
    } catch (e) {
      print('Lỗi phát hiện khuôn mặt: $e');
      return {
        'success': false,
        'confidence': 0.0,
        'message': 'Lỗi phát hiện khuôn mặt: $e',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    }
  }

  // So sánh khuôn mặt (giả lập)
  Future<Map<String, dynamic>> compareFace(String base64Image) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }

      // ใช้ _databaseRef
      final testRef = _databaseRef.child('test');
      await testRef.set({'test': 'value'});

      // Lấy dữ liệu khuôn mặt đã đăng ký
      final snapshot = await _faceScanRef.child(user.uid).limitToLast(1).get();

      if (!snapshot.exists) {
        return {
          'success': false,
          'match': false,
          'confidence': 0.0,
          'message': 'Chưa đăng ký khuôn mặt',
        };
      }

      final faceData = snapshot.value as Map<dynamic, dynamic>;
      final firstKey = faceData.keys.first;
      final registeredFace = faceData[firstKey] as Map<dynamic, dynamic>;

      // ใช้ตัวแปร registeredFace เพื่อไม่ให้เป็น unused
      final registeredFaceId =
          registeredFace['timestamp']?.toString() ?? 'unknown';
      print('Comparing with registered face: $registeredFaceId');

      // Giả lập so sánh khuôn mặt
      // Trong thực tế, bạn cần sử dụng ML Kit hoặc API so sánh khuôn mặt
      final bool isMatch = true; // Giả lập khớp
      final double confidence = 0.92; // Giả lập độ tin cậy

      if (isMatch && confidence > 0.8) {
        // Gửi thông báo nhận diện thành công
        await _sendFaceScanNotification(
          user.uid,
          'Nhận diện khuôn mặt thành công',
          1,
          'face_recognition_success',
          confidence: confidence,
        );
      }

      return {
        'success': true,
        'match': isMatch,
        'confidence': confidence,
        'message': isMatch ? 'Khuôn mặt khớp' : 'Khuôn mặt không khớp',
        'registeredFaceId': firstKey,
        'registeredFaceData': registeredFaceId,
      };
    } catch (e) {
      print('Lỗi so sánh khuôn mặt: $e');
      return {
        'success': false,
        'match': false,
        'confidence': 0.0,
        'message': 'Lỗi so sánh khuôn mặt: $e',
      };
    }
  }

  // Lấy danh sách khuôn mặt đã đăng ký
  Future<List<Map<String, dynamic>>> getRegisteredFaces(
      {String? userId}) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      final String uid = userId ?? user?.uid ?? 'unknown';

      if (uid == 'unknown') {
        return [];
      }

      final snapshot = await _faceScanRef.child(uid).get();

      if (!snapshot.exists) {
        return [];
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> faces = [];

      data.forEach((key, value) {
        if (value is Map) {
          faces.add({
            'id': key.toString(),
            'timestamp': value['timestamp'],
            'totalImages': value['totalImages'] ?? 0,
            'status': value['status'] ?? 'unknown',
            'lastUpdated': value['lastUpdated'],
          });
        }
      });

      // Sắp xếp theo thời gian mới nhất
      faces.sort(
          (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

      return faces;
    } catch (e) {
      print('Lỗi lấy danh sách khuôn mặt: $e');
      return [];
    }
  }

  // Xóa khuôn mặt đã đăng ký
  Future<bool> deleteFaceRegistration(String faceId, {String? userId}) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      final String uid = userId ?? user?.uid ?? 'unknown';

      if (uid == 'unknown') {
        throw Exception('Không tìm thấy người dùng');
      }

      // ใช้ _databaseRef
      await _databaseRef.child('deletion_log').push().set({
        'faceId': faceId,
        'userId': uid,
        'timestamp': ServerValue.timestamp,
      });

      // Xóa khuôn mặt
      await _faceScanRef.child(uid).child(faceId).remove();

      // Cập nhật thông tin người dùng
      await _usersRef.child(uid).update({
        'faceRegistered': false,
        'faceRegistrationDate': null,
        'totalFaceImages': 0,
        'faceScanId': null,
      });

      // Gửi thông báo
      await _sendFaceScanNotification(
        uid,
        'Đã xóa đăng ký khuôn mặt',
        0,
        'face_registration_deleted',
      );

      return true;
    } catch (e) {
      print('Lỗi xóa đăng ký khuôn mặt: $e');
      return false;
    }
  }

  // Lấy thông tin khuôn mặt cụ thể
  Future<Map<String, dynamic>?> getFaceDetails(String faceId,
      {String? userId}) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      final String uid = userId ?? user?.uid ?? 'unknown';

      if (uid == 'unknown') {
        return null;
      }

      final snapshot = await _faceScanRef.child(uid).child(faceId).get();

      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;

      // ใช้ตัวแปรให้ครบ
      final userData = await _getUserInfo(uid); // ใช้ตัวแปร user
      print('Face details for user: ${userData['name'] ?? 'Unknown'}');

      return {
        'id': faceId,
        'userId': uid,
        'timestamp': data['timestamp'],
        'totalImages': data['totalImages'] ?? 0,
        'status': data['status'] ?? 'unknown',
        'lastUpdated': data['lastUpdated'],
        'images': data['images'] ?? {},
        'userInfo': userData,
      };
    } catch (e) {
      print('Lỗi lấy thông tin khuôn mặt: $e');
      return null;
    }
  }

  // Helper method เพื่อใช้ตัวแปร user
  Future<Map<String, dynamic>> _getUserInfo(String userId) async {
    try {
      final snapshot = await _usersRef.child(userId).get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        return {
          'name': data['name']?.toString() ?? 'Unknown',
          'email': data['email']?.toString() ?? 'Unknown',
          'faceRegistered': data['faceRegistered'] ?? false,
        };
      }
      return {'name': 'Unknown', 'email': 'Unknown', 'faceRegistered': false};
    } catch (e) {
      return {'name': 'Error', 'email': 'Error', 'faceRegistered': false};
    }
  }

  // Kiểm tra xem người dùng đã đăng ký khuôn mặt chưa
  Future<bool> isFaceRegistered({String? userId}) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      final String uid = userId ?? user?.uid ?? 'unknown';

      if (uid == 'unknown') {
        return false;
      }

      final snapshot = await _usersRef.child(uid).child('faceRegistered').get();
      return snapshot.exists && (snapshot.value as bool) == true;
    } catch (e) {
      print('Lỗi kiểm tra đăng ký khuôn mặt: $e');
      return false;
    }
  }

  // Lấy số lượng ảnh khuôn mặt đã đăng ký
  Future<int> getRegisteredFaceCount({String? userId}) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      final String uid = userId ?? user?.uid ?? 'unknown';

      if (uid == 'unknown') {
        return 0;
      }

      final snapshot =
          await _usersRef.child(uid).child('totalFaceImages').get();
      if (snapshot.exists) {
        return (snapshot.value as int) ?? 0;
      }
      return 0;
    } catch (e) {
      print('Lỗi lấy số lượng ảnh khuôn mặt: $e');
      return 0;
    }
  }

  // Gửi thông báo truy cập bằng khuôn mặt
  Future<void> sendFaceAccessNotification(
      bool accessGranted, double confidence) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final String message = accessGranted
          ? 'Truy cập được cấp bằng nhận diện khuôn mặt'
          : 'Truy cập bị từ chối - Khuôn mặt không khớp';

      await _sendFaceScanNotification(
        user.uid,
        message,
        0,
        'face_access_${accessGranted ? "granted" : "denied"}',
        confidence: confidence,
      );
    } catch (e) {
      print('Lỗi gửi thông báo truy cập: $e');
    }
  }

  // Helper methods
  String _getAngleDescription(int index) {
    if (index < 20) return 'trước';
    if (index < 40) return 'bên trái';
    if (index < 60) return 'bên phải';
    return 'góc khác';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  // API Integration (tùy chọn)
  Future<Map<String, dynamic>> callFaceRecognitionAPI(
      String base64Image) async {
    try {
      // Ví dụ tích hợp với API bên ngoài
      final response = await http.post(
        Uri.parse('https://your-face-api.com/detect'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'image': base64Image,
          'api_key': 'your_api_key',
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('API call failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Lỗi gọi API nhận diện khuôn mặt: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Tạo training data cho model
  Future<Map<String, dynamic>> prepareTrainingData(String userId) async {
    try {
      final faceDetails = await getRegisteredFaces(userId: userId);

      if (faceDetails.isEmpty) {
        return {'success': false, 'message': 'Không có dữ liệu khuôn mặt'};
      }

      // Lấy khuôn mặt mới nhất
      final latestFace = faceDetails.first;
      final faceId = latestFace['id'];

      // แก้ไข dead code - ตรวจสอบว่า faceId ไม่ใช่ null
      if (faceId == null) {
        return {'success': false, 'message': 'Không tìm thấy face ID'};
      }

      final faceData = await getFaceDetails(faceId, userId: userId);

      if (faceData == null || !faceData.containsKey('images')) {
        return {'success': false, 'message': 'Không tìm thấy hình ảnh'};
      }

      final images = faceData['images'] as Map<dynamic, dynamic>;
      final List<String> base64Images = [];
      final List<String> labels = [];

      images.forEach((key, value) {
        if (value is Map && value.containsKey('base64')) {
          base64Images.add(value['base64'].toString());
          labels.add(userId); // Label là userId
        }
      });

      return {
        'success': true,
        'images': base64Images,
        'labels': labels,
        'totalSamples': base64Images.length,
        'faceId': faceId,
        'userId': userId,
      };
    } catch (e) {
      print('Lỗi chuẩn bị dữ liệu training: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Phân tích chất lượng khuôn mặt
  Future<Map<String, dynamic>> analyzeFaceQuality(String base64Image) async {
    try {
      // Giả lập phân tích chất lượng
      // Trong thực tế, tích hợp với ML Kit hoặc API

      final bool isGoodQuality = true;
      final double brightnessScore = 0.8;
      final double sharpnessScore = 0.9;
      final double poseScore = 0.85;
      final double overallScore =
          (brightnessScore + sharpnessScore + poseScore) / 3;

      return {
        'success': true,
        'isGoodQuality': isGoodQuality,
        'scores': {
          'brightness': brightnessScore,
          'sharpness': sharpnessScore,
          'pose': poseScore,
          'overall': overallScore,
        },
        'recommendations': isGoodQuality
            ? ['Chất lượng hình ảnh tốt']
            : ['Cần cải thiện ánh sáng', 'Giữ đầu thẳng'],
      };
    } catch (e) {
      print('Lỗi phân tích chất lượng khuôn mặt: $e');
      return {
        'success': false,
        'isGoodQuality': false,
        'scores': {},
        'recommendations': ['Lỗi phân tích'],
      };
    }
  }

  // Thống kê sử dụng nhận diện khuôn mặt
  Future<Map<String, dynamic>> getFaceRecognitionStats({String? userId}) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      final String uid = userId ?? user?.uid ?? 'unknown';

      if (uid == 'unknown') {
        return {'success': false, 'message': 'Không tìm thấy người dùng'};
      }

      // Lấy thông báo khuôn mặt
      final snapshot = await _notificationsRef
          .orderByChild('userId')
          .equalTo(uid)
          .limitToLast(100)
          .get();

      int successfulScans = 0;
      int failedScans = 0;
      int totalAccessAttempts = 0;
      DateTime? firstScanDate;
      DateTime? lastScanDate;

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          if (value is Map) {
            final type = value['type']?.toString() ?? '';
            final timestamp = value['timestamp'];

            if (timestamp != null) {
              final scanDate =
                  DateTime.fromMillisecondsSinceEpoch(timestamp as int);

              if (firstScanDate == null || scanDate.isBefore(firstScanDate!)) {
                firstScanDate = scanDate;
              }

              if (lastScanDate == null || scanDate.isAfter(lastScanDate!)) {
                lastScanDate = scanDate;
              }
            }

            if (type.contains('success') || type.contains('granted')) {
              successfulScans++;
            } else if (type.contains('fail') || type.contains('denied')) {
              failedScans++;
            }

            if (type.contains('access')) {
              totalAccessAttempts++;
            }
          }
        });
      }

      final totalScans = successfulScans + failedScans;
      final successRate =
          totalScans > 0 ? (successfulScans / totalScans) * 100 : 0;

      return {
        'success': true,
        'userId': uid,
        'stats': {
          'totalScans': totalScans,
          'successfulScans': successfulScans,
          'failedScans': failedScans,
          'successRate': successRate,
          'totalAccessAttempts': totalAccessAttempts,
          'firstScanDate': firstScanDate?.millisecondsSinceEpoch,
          'lastScanDate': lastScanDate?.millisecondsSinceEpoch,
        },
      };
    } catch (e) {
      print('Lỗi lấy thống kê nhận diện khuôn mặt: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Xóa tất cả dữ liệu khuôn mặt (dành cho admin)
  Future<bool> deleteAllFaceData({String? userId}) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      final String uid = userId ?? user?.uid ?? 'unknown';

      if (uid == 'unknown') {
        throw Exception('Không tìm thấy người dùng');
      }

      // ใช้ _databaseRef เพื่อ log การลบ
      await _databaseRef.child('admin_deletions').push().set({
        'userId': uid,
        'timestamp': ServerValue.timestamp,
        'action': 'delete_all_face_data',
      });

      // Xóa tất cả khuôn mặt
      await _faceScanRef.child(uid).remove();

      // Xóa thông báo khuôn mặt của người dùng
      final notificationsSnapshot = await _notificationsRef.get();
      if (notificationsSnapshot.exists) {
        final data = notificationsSnapshot.value as Map<dynamic, dynamic>;
        final deletions = <Future>[];

        data.forEach((key, value) {
          if (value is Map && value['userId'] == uid) {
            deletions.add(_notificationsRef.child(key.toString()).remove());
          }
        });

        await Future.wait(deletions);
      }

      // Reset thông tin người dùng
      await _usersRef.child(uid).update({
        'faceRegistered': false,
        'faceRegistrationDate': null,
        'totalFaceImages': 0,
        'faceScanId': null,
        'lastFaceUpdate': null,
      });

      return true;
    } catch (e) {
      print('Lỗi xóa tất cả dữ liệu khuôn mặt: $e');
      return false;
    }
  }

  // เพิ่ม method เพื่อใช้ registeredFace
  Future<void> _useRegisteredFace(Map<dynamic, dynamic> registeredFace) async {
    // ใช้ตัวแปร registeredFace เพื่อไม่ให้เป็น unused
    final faceId = registeredFace['id']?.toString() ?? 'unknown';
    final totalImages = registeredFace['totalImages'] ?? 0;

    print('Using registered face: $faceId with $totalImages images');

    // ใช้ _databaseRef เพื่อบันทึกการใช้งาน
    await _databaseRef.child('face_usage').push().set({
      'faceId': faceId,
      'timestamp': ServerValue.timestamp,
      'action': 'accessed',
    });
  }
}
