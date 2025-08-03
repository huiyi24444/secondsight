import 'package:flutter/material.dart';
import '../../../model/admin_model.dart';


class AdminSessionService extends ChangeNotifier {
  static AdminSessionService? _instance;

  // Singleton pattern
  static AdminSessionService get instance {
    _instance ??= AdminSessionService();
    return _instance!;
  }

  AdminModel? _currentAdmin;
  String? _ipAddress;
  String? _userAgent;
  String? _deviceInfo;

  AdminModel? get currentAdmin => _currentAdmin;
  String? get ipAddress => _ipAddress;
  String? get userAgent => _userAgent;
  String? get deviceInfo => _deviceInfo;

  void setCurrentAdmin(AdminModel admin) {
    _currentAdmin = admin;
    notifyListeners();
  }

  void setDeviceInfo({String? ip, String? userAgent, String? device}) {
    _ipAddress = ip;
    _userAgent = userAgent;
    _deviceInfo = device;
  }

  void clearSession() {
    _currentAdmin = null;
    _ipAddress = null;
    _userAgent = null;
    _deviceInfo = null;
    notifyListeners();
  }

  // Helper method for easy logging
  Map<String, dynamic> get logInfo => {
    'adminId': _currentAdmin?.id ?? '',
    'adminEmail': _currentAdmin?.email ?? '',
    'adminName': _currentAdmin?.name ?? '',
    'adminRole': _currentAdmin?.role ?? '',
    'ipAddress': _ipAddress,
    'userAgent': _userAgent,
    'deviceInfo': _deviceInfo,
  };
}
