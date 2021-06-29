import 'package:flash_chat_app/main.dart';
import 'package:flash_chat_app/repository/themeRepository.dart';
import 'package:flash_chat_app/repository/userRepository.dart';
import 'package:flutter/material.dart';
import 'package:flash_chat_app/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

final _firestore = FirebaseFirestore.instance;
late final User loggedInUser;
late final User messageSender;

class ChatScreen extends StatefulWidget {
  static const String id = "chat_screen";
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final messageTextController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  String messageText = "";
  @override
  void initState() {
    // todo implement initState
    //completed...
    super.initState();
    getCurrentUser();
  }

  void getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        loggedInUser = user;
        print(loggedInUser.email);
      }
    } catch (e) {
      print(e);
    }
  }

  void messageStream() async {
    await for (var snapshot in _firestore.collection('messages').snapshots()) {
      for (QueryDocumentSnapshot message in snapshot.docs) {
        var data = message.data();
        print(data);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final _userRepository = Provider.of<UserRepository>(context);
    final _themeRepository = Provider.of<ThemeRepository>(context);
    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          IconButton(
              icon: Icon(Icons.logout),
              tooltip: 'Log out',
              onPressed: () {
                _userRepository.logout();
              }),
          IconButton(
              icon: Icon(Icons.album_sharp),
              onPressed: () {
                _themeRepository.toggleThemeState();
              })
        ],
        title: Text('⚡️Chat'),
        backgroundColor: Theme.of(context).accentColor,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MessagesStream(),
            Container(
              decoration: kMessageContainerDecoration,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: messageTextController,
                      onChanged: (value) {
                        //Do something with the user input.
                        //task completed
                        messageText = value;
                      },
                      decoration: kMessageTextFieldDecoration,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      //message Text + loggedInUser.email
                      if (messageTextController.text.trim().isNotEmpty) {
                        messageTextController.clear();
                        _firestore.collection('messages').add(
                          {
                            'text': messageText.trim(),
                            'sender': loggedInUser.email,
                            'time': DateTime.now().millisecondsSinceEpoch,
                            'senderUid': FirebaseAuth.instance.currentUser!.uid,
                          },
                        );
                      }
                    },
                    child: Text(
                      'Send',
                      style: kSendButtonTextStyle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  MessageBubble(
      {required this.sender, required this.text, required this.senderUid});
  final String sender;
  final String text;
  final String senderUid;

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Padding(
      padding: EdgeInsets.all(size.width * .02),
      child: Column(
        crossAxisAlignment: senderUid == FirebaseAuth.instance.currentUser!.uid
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Text(sender, style: TextStyle(color: Colors.black54, fontSize: 12)),
          Container(
            constraints: BoxConstraints(maxWidth: size.width * 0.7),
            child: Material(
              elevation: size.width * .01,
              borderRadius: BorderRadius.only(
                topLeft: senderUid == FirebaseAuth.instance.currentUser!.uid
                    ? Radius.circular(size.height * .05)
                    : Radius.zero,
                topRight: senderUid != FirebaseAuth.instance.currentUser!.uid
                    ? Radius.circular(size.height * .05)
                    : Radius.zero,
                bottomLeft: Radius.circular(size.height * .05),
                bottomRight: Radius.circular(size.height * .05),
              ),
              color: senderUid == FirebaseAuth.instance.currentUser!.uid
                  ? Colors.blueAccent[400]
                  : Colors.pinkAccent[400],
              child: Padding(
                padding: EdgeInsets.symmetric(
                    vertical: size.height * .015, horizontal: size.width * .05),
                child: Text(
                  text,
                  style: TextStyle(
                      fontSize: size.width * .04, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessagesStream extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('messages')
          .orderBy('time', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        //s print(snapshot.data!.docs[0]['text']);
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              backgroundColor: Colors.blue,
            ),
          );
        } else {
          var messageList = snapshot.data!.docs;

          return messageList.isNotEmpty
              ? Expanded(
                  child: ListView(
                    reverse: true,
                    padding: EdgeInsets.only(left: 10),
                    children: [
                      // for (var message in messageList)
                      for (int i = messageList.length - 1; i >= 0; i--)
                        MessageBubble(
                          sender: messageList[i]['sender'],
                          text: messageList[i]['text'],
                          senderUid: messageList[i]['senderUid'] ?? '',
                        ),
                      // Text(message['text'] +
                      //     '  from  ' +
                      //     message['sender']),
                    ],
                  ),
                )
              : Center(
                  child: CircularProgressIndicator(
                      backgroundColor: Colors.blueAccent[400]),
                );
        }
        // final messages = snapshot.data;
        // List<Text> messageWidgets = [];
        // for (var message in messages) {
        //   final messageText = message.data['text'];
        //   final messageSender = message.data['sender'];
        //   final messageWidget =
        //       Text('$messageText from $messageSender');
        //   messageWidgets.add(messageWidget);
        // }
      },
    );
  }
}
