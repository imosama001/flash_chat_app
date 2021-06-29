import 'dart:io';

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

  void setDarkTheme() {
    _themeState = ThemeState.dark;
    notifyListeners();
  }

  void setLightTheme() {
    _themeState = ThemeState.light;
    notifyListeners();
  }

  void setThemeAsSystem(BuildContext context) {
    MediaQuery.of(context).platformBrightness == Brightness.dark
        ? _themeState = ThemeState.dark
        : _themeState = ThemeState.light;
    notifyListeners();
  }
}
