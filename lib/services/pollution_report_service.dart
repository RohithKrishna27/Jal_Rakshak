import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Citizen pollution reports → Firestore `pollution_reports`.
class PollutionReportService {
  PollutionReportService._();

  static final _fire = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _fire.collection('pollution_reports');

  static Stream<QuerySnapshot<Map<String, dynamic>>> reportsStream({int limit = 80}) {
    return _col.orderBy('createdAt', descending: true).limit(limit).snapshots();
  }

  static Future<void> submit({
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

    await _col.add({
      'suspectedCompanyName': suspectedCompanyName.trim(),
      'companyAddress': companyAddress.trim(),
      'wasteType': wasteType.trim(),
      'description': description.trim(),
      'waterBody': waterBody.trim(),
      'locationNotes': locationNotes.trim(),
      'reporterUid': user.uid,
      'reporterEmail': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'submitted',
      'source': 'normal_user_app',
    });
  }
}
