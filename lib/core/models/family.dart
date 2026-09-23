import 'package:cloud_firestore/cloud_firestore.dart';

class Family {
  Family({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdBy,
    required this.memberUids,
    this.createdAt,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String createdBy;
  final List<String> memberUids;
  final DateTime? createdAt;

  bool get isOwner => createdBy == createdBy; // caller checks uid externally

  factory Family.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Family(
      id: doc.id,
      name: data['name'] ?? '',
      inviteCode: data['inviteCode'] ?? '',
      createdBy: data['createdBy'] ?? '',
      memberUids: List<String>.from(data['memberUids'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'inviteCode': inviteCode,
    'createdBy': createdBy,
    'memberUids': memberUids,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
  };
}
