import 'dart:io';
import 'package:flash_chat_app/constants.dart';
import 'package:flash_chat_app/repository/userRepository.dart';
import 'package:flutter/material.dart';
import 'package:flash_chat_app/components/rounded_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class RegistrationScreen extends StatefulWidget {
  static const String id = "registration_screen";
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _auth = FirebaseAuth.instance;
  String email = "";
  String password = "";
  String name = "";
  File? profileImage;

  @override
  Widget build(BuildContext context) {
    PickedFile? image; // profile image

    final _userRepository = Provider.of<UserRepository>(context);
    Size _size = MediaQuery.of(context).size;

    final picker = ImagePicker();
    return Scaffold(
      // backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            reverse: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Hero(
                  tag: 'logo',
                  child: Container(
                    height: _size.height * 0.15,
                    child: Image.asset('images/logo.png'),
                  ),
                ),
                SizedBox(height: _size.height * 0.05),
                GestureDetector(
                  onTap: () async {
                    image = await picker.getImage(
                      source: ImageSource.gallery,
                      imageQuality: 50,
                      maxHeight: 720,
                    );

                    if (mounted)
                      setState(() {
                        profileImage = File(image!.path);
                      });
                  },
                  child: CircleAvatar(
                    minRadius: 80,
                    maxRadius: 80,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage:
                        profileImage != null ? FileImage(profileImage!) : null,
                    child: profileImage != null
                        ? SizedBox()
                        : Icon(Icons.add_a_photo),
                  ),
                ),
                SizedBox(height: _size.height * 0.05),
                TextField(
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) {
                      email = value;
                    },
                    decoration: kTextFieldDecoration.copyWith(
                        hintText: "Enter your email ")),
                SizedBox(height: _size.height * 0.02),
                TextField(
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) {
                      name = value;
                    },
                    decoration: kTextFieldDecoration.copyWith(
                        hintText: "Enter your name ")),
                SizedBox(height: _size.height * 0.02),
                TextField(
                  textAlign: TextAlign.center,
                  obscureText: true,
                  onChanged: (value) {
                    password = value;
                  },
                  decoration: kTextFieldDecoration.copyWith(
                      hintText: "Enter you Password "),
                ),
                SizedBox(height: _size.height * 0.02),
                RoundedButton(
                  title: "Register",
                  colour: Colors.blueAccent,
                  onPressed: () async {
                    try {
                      // print(email);
                      // print(password);
                      if (name == '' && email == '' && password.length < 4) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Enter all fields')));
                      } else {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            duration: Duration(minutes: 1),
                            content: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Signing up'),
                                CircularProgressIndicator()
                              ],
                            )));
                        await _userRepository.signup(
                          email: email,
                          password: password,
                          name: name,
                          image: File(profileImage!.path),
                        );
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();

                      print(e);
                      String errorMsg = 'Signup failed';

                      if (e.toString().contains('invalid-email')) {
                        errorMsg = 'Invalid email';
                      }

                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(errorMsg)));
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
