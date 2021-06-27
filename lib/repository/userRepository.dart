import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AppState {
  initial,
  authenticated,
  authenticating,
  unauthenticated,
}

class UserRepository with ChangeNotifier {
  FirebaseAuth _auth;
  var _user;
  FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // final GoogleSignIn _googleSignIn;
  AppState _appState = AppState.initial;

  AppState get appState => _appState;
  get user => _user;

  UserRepository() : _auth = FirebaseAuth.instance {
    print('*' * 100);
    print('user repository initialised');
    print('*' * 100);
    // _appState = AppState.unauthenticated;

    _auth.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser == null) {
        _appState = AppState.unauthenticated;
        notifyListeners();
      } else {
        print('logged In');
        _user = firebaseUser;

        _appState = AppState.authenticated;
        notifyListeners();
      }
    });
  }

  Future<bool> isSignedIn() async {
    final currentUser = _firebaseAuth.currentUser;
    return currentUser != null;
  }

  Future<bool> isFirstTime(String userId) async {
    bool exist = false;
    await _firestore.collection('users').doc(userId).get().then((var user) {
      exist = user.exists;
    }).catchError((error) {
      exist = true;
    });

    return exist;
  }

  Future<dynamic> login(String email, String password) async {
    var user = await _auth
        .signInWithEmailAndPassword(email: email, password: password)
        .catchError((error) {
      print(error.code);
      _appState = AppState.unauthenticated;
      notifyListeners();

      throw error;
    });

    _appState = AppState.authenticated;
    notifyListeners();
    return user;
    // }
    //  catch (e) {
    //   print(e.toString() + '*******');
    //   _appState = AppState.unauthenticated;
    //   notifyListeners();
    //   throw e;
    // }
  }

  Future<dynamic> signup({
    required String email,
    required String password,
    required String name,
    required File image,
  }) async {
    _appState = AppState.authenticating;
    var user = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);

    // upload photo to firebase storage

    Reference firebaseStorageRef = FirebaseStorage.instance
        .ref()
        .child('profilePics')
        .child(FirebaseAuth.instance.currentUser!.uid);

    UploadTask uploadTask = firebaseStorageRef.putFile(image);

    TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);
    String imageUrl = await taskSnapshot.ref.getDownloadURL();

    await _firestore
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .set({
      'name': name,
      'email': email,
      'photoUrl': imageUrl,
      'uuid': FirebaseAuth.instance.currentUser!.uid,
      'joinDate': Timestamp.now(),
      'isAdmin': false,
    }).catchError((error) {
      _appState = AppState.unauthenticated;
      notifyListeners();

      throw error;
    });
  }

  Future logout() async {
    await _auth.signOut();

    _appState = AppState.unauthenticated;
    notifyListeners();
    return Future.delayed(Duration.zero);
  }

  Future<dynamic> getCurrentUserDetails() async {
    var _user = _firestore
        .collection('users')
        .doc(_firebaseAuth.currentUser!.uid)
        .get();
    return _user;
  }

  Future<void> updateUserProfile({
    required String name,
    required String phoneNumber,
    required String address,
    required String state,
    required String country,
    required File image,
  }) async {
    Reference firebaseStorageRef = FirebaseStorage.instance
        .ref()
        .child('profilePics')
        .child(FirebaseAuth.instance.currentUser!.uid);

    UploadTask uploadTask = firebaseStorageRef.putFile(image);

    TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);
    String imageUrl = await taskSnapshot.ref.getDownloadURL();

    _firestore.collection('users').doc(_firebaseAuth.currentUser!.uid).update({
      'name': name,
      'address': address,
      'state': state,
      'country': country,
      'phoneNumber': phoneNumber,
      'photoUrl': imageUrl,
    });
  }
}
