import 'package:firebase_core/firebase_core.dart';
import 'package:flash_chat_app/repository/themeRepository.dart';
import 'package:flash_chat_app/repository/userRepository.dart';
import 'package:flash_chat_app/screens/splashScreen.dart';
import 'package:flutter/material.dart';
import 'package:flash_chat_app/screens/welcome_screen.dart';
import 'package:flash_chat_app/screens/chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );

  runApp(
    MultiProvider(
      child: FlashChat(),
      providers: [
        ChangeNotifierProvider(
          create: (_) => UserRepository(),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeRepository(),
        ),
      ],
    ),
  );
}

ThemeData themeDataDark = ThemeData.dark().copyWith(
  accentColor: Colors.redAccent,
);

ThemeData themeDataLight = ThemeData.light().copyWith(
    // accentColor: Colors.redAccent,
    );

ThemeData theme = themeDataLight;

ThemeData toggleTheme() {
  return theme == themeDataDark ? themeDataLight : themeDataDark;
}

class FlashChat extends StatefulWidget {
  @override
  _FlashChatState createState() => _FlashChatState();
}

class _FlashChatState extends State<FlashChat> {
  DateTime? currentBackPressTime;

  @override
  Widget build(BuildContext context) {
    Firebase.initializeApp();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: getThemeData(context),
      home: _showScreen(context),
    );
  }
}

ThemeData getThemeData(BuildContext context) {
  switch (context.watch<ThemeRepository>().themeState) {
    case ThemeState.dark:
      return themeDataDark;
    case ThemeState.light:
      return themeDataLight;
  }
}

Widget _showScreen(BuildContext context) {
  switch (context.watch<UserRepository>().appState) {
    case AppState.authenticating:
      return SplashScreen();

    case AppState.unauthenticated:
      print(context.watch<UserRepository>().appState);
      return WelcomeScreen();

    case AppState.initial:
      return SplashScreen();

    case AppState.authenticated:
      print(context.watch<UserRepository>().appState);
      return ChatScreen();
  }
}
