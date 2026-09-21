import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthRepository extends ValueNotifier<UserModel?> {
  AuthRepository._()
      : super(
          const UserModel(
            id: 'user_1',
            name: 'David Miller',
            email: 'david.miller@example.com',
            familySpaceId: 'space_miller_1',
          ),
        );

  static final instance = AuthRepository._();

  bool get isAuthenticated => value != null;

  void login(String email, String password) {
    value = UserModel(
      id: 'user_1',
      name: email.split('@')[0].replaceAll('.', ' '),
      email: email,
      familySpaceId: 'space_miller_1',
    );
  }

  void register(String name, String email, String password) {
    value = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
    );
  }

  void logout() {
    value = null;
  }
}
