import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum ThemeState { light, dark }

class ThemeRepository with ChangeNotifier {
  ThemeState _themeState = ThemeState.dark;

  ThemeState get themeState => _themeState;
  void toggleThemeState() {
    _themeState =
        _themeState == ThemeState.dark ? ThemeState.light : ThemeState.dark;
    notifyListeners();
  }
}
