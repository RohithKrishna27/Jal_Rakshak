import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Citizen pollution reports → Firestore `pollution_reports` + optional photo in Storage.
class PollutionReportService {
  PollutionReportService._();

  static final _fire = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _fire.collection('pollution_reports');

  static Stream<QuerySnapshot<Map<String, dynamic>>> reportsStream({int limit = 80}) {
    return _col.orderBy('createdAt', descending: true).limit(limit).snapshots();
  }

  /// Uploads image bytes when non-null, then creates the report document.
  static Future<void> submit({
    required Uint8List? imageBytes,
    required String suspectedCompanyName,
    required String companyAddress,
    required String wasteType,
    required String description,
    String waterBody = '',
    String locationNotes = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign in to submit a pollution report.');
    }

    String? photoUrl;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final path =
          'pollution_reports/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(path);
      await ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      photoUrl = await ref.getDownloadURL();
    }

    await _col.add({
      'suspectedCompanyName': suspectedCompanyName.trim(),
      'companyAddress': companyAddress.trim(),
      'wasteType': wasteType.trim(),
      'description': description.trim(),
      'waterBody': waterBody.trim(),
      'locationNotes': locationNotes.trim(),
      'photoUrl': photoUrl,
      'reporterUid': user.uid,
      'reporterEmail': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'submitted',
      'source': 'normal_user_app',
    });
  }
}
