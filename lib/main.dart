import 'package:firebase_core/firebase_core.dart';
import 'package:flash_chat_app/repository/userRepository.dart';
import 'package:flutter/material.dart';
import 'package:flash_chat_app/screens/welcome_screen.dart';
import 'package:flash_chat_app/screens/login_screen.dart';
import 'package:flash_chat_app/screens/registration_screen.dart';
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
      ],
    ),
  );
}

class FlashChat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Firebase.initializeApp();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _showScreen(context),
    );
  }
}

Widget _showScreen(BuildContext context) {
  print(context.watch<UserRepository>().appState);
  switch (context.watch<UserRepository>().appState) {
    case AppState.authenticating:
      print(context.watch<UserRepository>().appState);
      return Container(
          child: Center(
              child:
                  CircularProgressIndicator())); // TODO: create loading screen

    case AppState.unauthenticated:
      print(context.watch<UserRepository>().appState);
      return WelcomeScreen();

    case AppState.initial:
      return Container(
          child: Center(
              child:
                  CircularProgressIndicator())); // TODO: create splash screen

    case AppState.authenticated:
      print(context.watch<UserRepository>().appState);
      return ChatScreen();
  }
}
