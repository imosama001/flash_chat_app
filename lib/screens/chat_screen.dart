import 'package:flutter/material.dart';
import 'package:flash_chat_app/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      final user = await _auth.currentUser;
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
    return Scaffold(
      appBar: AppBar(
        leading: null,
        actions: <Widget>[
          IconButton(
              icon: Icon(Icons.close),
              onPressed: () {
                //Implement logout functionality
                // _auth.signOut();
                // Navigator.pop(context);
                messageStream();
              }),
        ],
        title: Text('⚡️Chat'),
        backgroundColor: Colors.lightBlueAccent,
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
                      messageTextController.clear();
                      _firestore.collection('messages').add({
                        'text': messageText,
                        'sender': loggedInUser.email,
                        'time': DateTime.now().millisecondsSinceEpoch,
                      });
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
  MessageBubble({
    required this.sender,
    required this.text,
  });
  final String sender;
  final String text;

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Padding(
      padding: EdgeInsets.all(size.width * .02),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(sender, style: TextStyle(color: Colors.black54, fontSize: 12)),
          Material(
            elevation: size.width * .01,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(size.height * .05),
              bottomLeft: Radius.circular(size.height * .05),
              bottomRight: Radius.circular(size.height * .05),
            ),
            color: Colors.blueAccent[400],
            child: Padding(
              padding: EdgeInsets.symmetric(
                  vertical: size.height * .015, horizontal: size.width * .05),
              child: Text(
                text,
                style:
                    TextStyle(fontSize: size.width * .04, color: Colors.white),
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
                    padding: EdgeInsets.only(left: 10),
                    children: [
                      for (var message in messageList)
                        MessageBubble(
                          sender: message['sender'],
                          text: message['text'],
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
