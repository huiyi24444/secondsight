import 'package:flutter/material.dart';
//import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider with ChangeNotifier {
  String _userId = 'sBblLZO4yToH2lCJjw4N'; // 🔒 Hardcoded for now
  //String? _userId;

  String get userId => _userId;

  // In future, this can call FirebaseAuth to get actual user
  void setUserId(String id) {
    _userId = id;
    notifyListeners();
  }
  Future<void> signOut() async {
    //await FirebaseAuth.instance.signOut();
    //_userId = null;
    notifyListeners();
  }

}
