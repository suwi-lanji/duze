// core/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../../../core/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream to listen to authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    UserCredential userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return userCredential.user;
  }




  // Register with email and password
  Future<User?> registerWithEmail(String email, String password, String displayName) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _updateUserData(userCredential.user!, displayName);
    return userCredential.user;
  }

  // Update user data in Firestore
  Future<void> _updateUserData(User user, String displayName) async {
    UserModel userModel = UserModel(uid: user.uid, displayName: displayName, email: user.email ?? '', createdAt: DateTime.now());
    await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    return UserModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  // Sign in with Facebook
  Future<User?> signInWithFacebook() async {
    final LoginResult result = await FacebookAuth.instance.login();
    if (result.status == LoginStatus.success) {
      final credential = FacebookAuthProvider.credential(result.accessToken!.token);
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    }
    return null;
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await FacebookAuth.instance.logOut();
  }
}