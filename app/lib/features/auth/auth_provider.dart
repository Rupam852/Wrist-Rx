import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../shared/models/models.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final userModelProvider = StateNotifierProvider<UserNotifier, UserModel?>((ref) {
  return UserNotifier();
});

class UserNotifier extends StateNotifier<UserModel?> {
  UserNotifier() : super(null);

  final _api = ApiService();

  Future<({bool isNewUser})> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw Exception('Sign in cancelled');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await FirebaseAuth.instance.signInWithCredential(credential);

    // Register/fetch from backend
    try {
      final result = await _api.post(ApiConstants.register, {});
      final user = UserModel.fromJson(result['user']);
      state = user;
      return (isNewUser: result['isNewUser'] == true);
    } catch (_) {
      final current = FirebaseAuth.instance.currentUser!;
      state = UserModel(
        uid: current.uid,
        name: current.displayName ?? 'User',
        email: current.email ?? '',
        photoUrl: current.photoURL ?? '',
        isFirstLogin: false,
        profile: UserProfile(),
        settings: UserSettings(),
        watchInfo: WatchInfo(),
      );
      return (isNewUser: false);
    }
  }

  Future<void> fetchUser() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;
    try {
      final result = await _api.get(ApiConstants.getUser(firebaseUser.uid));
      state = UserModel.fromJson(result['user']);
    } catch (_) {
      // Fallback offline user model so app auto-logins seamlessly
      state = UserModel(
        uid: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'User',
        email: firebaseUser.email ?? '',
        photoUrl: firebaseUser.photoURL ?? '',
        isFirstLogin: false,
        profile: UserProfile(),
        settings: UserSettings(),
        watchInfo: WatchInfo(),
      );
    }
  }

  Future<void> updateProfile({String? name, String? photoUrl}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (photoUrl != null) body['photoUrl'] = photoUrl;
    try {
      final result = await _api.put(ApiConstants.updateUser(uid), body);
      state = UserModel.fromJson(result['user']);
    } catch (_) {
      if (state != null) {
        state = state!.copyWith(
          name: name ?? state!.name,
          photoUrl: photoUrl ?? state!.photoUrl,
        );
      }
    }
  }

  Future<void> saveOnboarding(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final result = await _api.put(ApiConstants.saveOnboarding(uid), data);
      state = UserModel.fromJson(result['user']);
    } catch (_) {}
  }

  Future<void> updateSettings(UserSettings settings) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final result = await _api.put(ApiConstants.updateUser(uid), {'settings': settings.toJson()});
      state = UserModel.fromJson(result['user']);
    } catch (_) {
      if (state != null) {
        state = state!.copyWith(settings: settings);
      }
    }
  }

  Future<void> signOut() async {
    try { await GoogleSignIn().signOut(); } catch (_) {}
    await FirebaseAuth.instance.signOut();
    state = null;
  }
}
