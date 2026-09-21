import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/family_space.dart';

class FamilyRepository extends ValueNotifier<FamilySpace?> {
  FamilyRepository._()
      : super(
          const FamilySpace(
            id: 'space_miller_1',
            name: 'The Miller Family Space',
            inviteCode: 'WM-8K92F',
            members: [
              SharedSpaceMember(
                id: 'm1',
                name: 'David Miller',
                email: 'david.miller@example.com',
                role: FamilyRole.owner,
              ),
              SharedSpaceMember(
                id: 'm2',
                name: 'Sarah Miller',
                email: 'sarah.m@example.com',
                role: FamilyRole.admin,
              ),
              SharedSpaceMember(
                id: 'm3',
                name: 'Leo Miller',
                email: 'leo@family.net',
                role: FamilyRole.member,
              ),
              SharedSpaceMember(
                id: 'm4',
                name: 'Emma Miller',
                email: 'emma@family.net',
                role: FamilyRole.viewOnly,
              ),
            ],
          ),
        );

  static final instance = FamilyRepository._();

  String generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    final code = List.generate(5, (_) => chars[rnd.nextInt(chars.length)]).join();
    return 'WM-$code';
  }

  void createSpace(String spaceName) {
    value = FamilySpace(
      id: 'space_${DateTime.now().millisecondsSinceEpoch}',
      name: spaceName,
      inviteCode: generateInviteCode(),
      members: [
        const SharedSpaceMember(
          id: 'user_owner',
          name: 'You (Owner)',
          email: 'user@example.com',
          role: FamilyRole.owner,
        ),
      ],
    );
  }

  bool joinSpaceWithKey(String code) {
    if (code.trim().isEmpty) return false;
    final formatted = code.trim().toUpperCase();
    value = FamilySpace(
      id: 'space_joined_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Joined Shared Space ($formatted)',
      inviteCode: formatted,
      members: [
        const SharedSpaceMember(
          id: 'owner_space',
          name: 'Space Host',
          email: 'host@family.com',
          role: FamilyRole.owner,
        ),
        const SharedSpaceMember(
          id: 'current_user',
          name: 'You',
          email: 'me@example.com',
          role: FamilyRole.member,
        ),
      ],
    );
    return true;
  }

  void updateMemberRole(String memberId, FamilyRole newRole) {
    if (value == null) return;
    final updatedMembers = value!.members.map((m) {
      if (m.id == memberId) {
        return m.copyWith(role: newRole);
      }
      return m;
    }).toList();
    value = value!.copyWith(members: updatedMembers);
  }

  void removeMember(String memberId) {
    if (value == null) return;
    final updatedMembers = value!.members.where((m) => m.id != memberId).toList();
    value = value!.copyWith(members: updatedMembers);
  }

  void leaveSpace() {
    value = null;
  }

  void regenerateInviteKey() {
    if (value == null) return;
    value = value!.copyWith(inviteCode: generateInviteCode());
  }
}
