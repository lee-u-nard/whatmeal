import 'package:cloud_firestore/cloud_firestore.dart';

/// A cooperative client quota, not a server-enforced billing/security boundary.
class AiQuotaStore {
  AiQuotaStore(this.firestore, {DateTime Function()? now})
      : now = now ?? DateTime.now;
  final FirebaseFirestore firestore;
  final DateTime Function() now;

  String _date() {
    final date = now();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      firestore.doc('users/$uid/usageCounters/daily');

  int _count(Map<String, dynamic>? data, String date) {
    if (data?['date'] != date) return 0;
    final count = data?['count'];
    if (count is! int || count < 0) {
      throw StateError('Invalid AI quota counter. Please try again later.');
    }
    return count;
  }

  Future<int> remaining(String uid, int limit) async =>
      (limit - _count((await _ref(uid).get()).data(), _date())).clamp(0, limit);

  /// Reserve before dispatch. Failed/ambiguous requests retain their reservation
  /// because a timeout does not prove that the provider did not process it.
  /// Returns null if exhausted, otherwise remaining requests after reservation.
  Future<int?> reserve(String uid, int limit) async {
    final date = _date();
    final ref = _ref(uid);
    return firestore.runTransaction((transaction) async {
      final count = _count((await transaction.get(ref)).data(), date);
      if (count >= limit) return null;
      transaction.set(ref, {'date': date, 'count': count + 1});
      return limit - count - 1;
    });
  }
}
