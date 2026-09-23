import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.familyId,
    this.createdAt,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? familyId;
  final DateTime? createdAt;

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AppUser(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      familyId: data['familyId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'familyId': familyId,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
  };

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    String? familyId,
    bool clearFamilyId = false,
  }) => AppUser(
    id: id,
    email: email,
    displayName: displayName ?? this.displayName,
    photoUrl: photoUrl ?? this.photoUrl,
    familyId: clearFamilyId ? null : (familyId ?? this.familyId),
    createdAt: createdAt,
  );
}
