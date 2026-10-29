import 'package:cloud_firestore/cloud_firestore.dart';

class Family {
  Family({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdBy,
    required this.memberUids,
    this.createdAt,
    this.ownerUid,
    this.state = 'active',
    this.schemaVersion = 1,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String createdBy;
  final List<String> memberUids;
  final DateTime? createdAt;
  final String? ownerUid;
  final String state;
  final int schemaVersion;

  bool isOwner(String? uid) => uid != null && uid == (ownerUid ?? createdBy);

  factory Family.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Family(
      id: doc.id,
      name: data['name'] ?? '',
      ownerUid: data['ownerUid'],
      state: data['state'] ?? 'active',
      schemaVersion: data['schemaVersion'] ?? 1,
      inviteCode: data['inviteCode'] ?? '',
      createdBy: data['createdBy'] ?? '',
      memberUids: List<String>.from(data['memberUids'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => schemaVersion == 2
      ? {
          'schemaVersion': 2,
          'name': name,
          'createdBy': createdBy,
          'ownerUid': ownerUid ?? createdBy,
          'state': state,
          'createdAt': createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }
      : {
          'name': name,
          'inviteCode': inviteCode,
          'createdBy': createdBy,
          'memberUids': memberUids,
          'createdAt': createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : FieldValue.serverTimestamp(),
        };
}
