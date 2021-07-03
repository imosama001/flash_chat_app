import 'package:flash_chat_app/main.dart';
import 'package:flash_chat_app/repository/themeRepository.dart';
import 'package:flash_chat_app/repository/userRepository.dart';
import 'package:flutter/material.dart';
import 'package:flash_chat_app/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

final _firestore = FirebaseFirestore.instance;
late final User loggedInUser;
late final User messageSender;
List<String> usersInChatUid = [];
final ScrollController _scrollController = ScrollController();

Color getColorByUid({required String uid}) {
  Color res = Colors.grey;
  if (usersInChatUid.isNotEmpty &&
      bubbleColor.length >= usersInChatUid.length &&
      usersInChatUid.contains(uid))
    res = bubbleColor[usersInChatUid.indexOf(uid)];
  return res;
}

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
    super.initState();
    usersInChatUid = [_auth.currentUser!.uid];
    _firestore.collection('users').get().then((data) {
      var docs = data.docs;
      docs.forEach((doc) {
        usersInChatUid.add(doc.id);
      });
      print(usersInChatUid);
    });
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

  DateTime? currentBackPressTime;
  Future<bool> onWillPop() {
    print('*' * 50);
    DateTime now = DateTime.now();
    if (currentBackPressTime == null ||
        now.difference(currentBackPressTime!) > Duration(seconds: 2)) {
      currentBackPressTime = now;
      Fluttertoast.showToast(msg: 'Back again to exit');
      return Future.value(false);
    }
    return Future.value(true);
  }

  @override
  Widget build(BuildContext context) {
    final _userRepository = Provider.of<UserRepository>(context);
    final _themeRepository = Provider.of<ThemeRepository>(context);

    // _scrollController.addListener(() {
    //   if (!_scrollController.position.atEdge)
    //     setState(() {
    //       scrolledAtEdge = false;
    //     });
    //   else if (!scrolledAtEdge)
    //     setState(() {
    //       scrolledAtEdge = true;
    //     });
    // });
    // bool atEdge() {
    //   if (mounted) setState(() {
    //     if
    //   });
    //   return _scrollController.position.atEdge;
    // }

    return WillPopScope(
      onWillPop: onWillPop,
      child: GestureDetector(
        // scroll to last on double tap anywhere
        onDoubleTap: () => _scrollController
            .animateTo(
          0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        )
            .catchError((onError) {
          print(onError);
        }),
        child: Scaffold(
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
                          String messageUid = Uuid().v4();
                          //message Text + loggedInUser.email
                          if (messageTextController.text.trim().isNotEmpty) {
                            messageTextController.clear();
                            _firestore
                                .collection('messages')
                                .doc(messageUid)
                                .set(
                              {
                                'text': messageText.trim(),
                                'sender': loggedInUser.email,
                                'time': DateTime.now().millisecondsSinceEpoch,
                                'senderUid':
                                    FirebaseAuth.instance.currentUser!.uid,
                                'messageUid': messageUid,
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
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  MessageBubble({
    required this.sender,
    required this.text,
    required this.senderUid,
    required this.messageUid,
    required this.time,
  });
  final String sender;
  final String text;
  final String senderUid;
  final String messageUid;
  final int time;

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    void deleteMessage({required String messageUid}) async {
      await _firestore.collection('messages').doc(messageUid).delete();
    }

    bool isNotLate() {
      return DateTime.now()
              .subtract(Duration(hours: 2))
              .millisecondsSinceEpoch <=
          time;
    }

    return GestureDetector(
      onLongPress: () {
        if (senderUid == FirebaseAuth.instance.currentUser!.uid && isNotLate())
          showDialog(
            context: context,
            builder: (ctxt) => AlertDialog(
              actions: [
                TextButton(
                    onPressed: () {
                      deleteMessage(messageUid: messageUid);
                      Navigator.of(ctxt).pop();
                    },
                    child: Text('Delete')),
                TextButton(
                    onPressed: () {
                      Navigator.of(ctxt).pop();
                    },
                    child: Text('Cancel')),
              ],
              content: Text('Delete this message?'),
            ),
          );
        else
          Fluttertoast.showToast(msg: 'Can not be deleted');
      },
      child: Padding(
        padding: EdgeInsets.all(size.width * .02),
        child: Column(
          crossAxisAlignment:
              senderUid == FirebaseAuth.instance.currentUser!.uid
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
                    : getColorByUid(uid: senderUid),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      vertical: size.height * .015,
                      horizontal: size.width * .05),
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
              strokeWidth: 5,
            ),
          );
        } else {
          var messageList = snapshot.data!.docs;

          return messageList.isNotEmpty
              ? Expanded(
                  child: ListView(
                    controller: _scrollController,
                    reverse: true,
                    padding: EdgeInsets.only(left: 10),
                    children: [
                      for (int i = messageList.length - 1; i >= 0; i--)
                        MessageBubble(
                          sender: messageList[i]['sender'],
                          text: messageList[i]['text'],
                          senderUid: messageList[i]['senderUid'],
                          messageUid: messageList[i]['messageUid'],
                          time: messageList[i]['time'],
                        ),
                      // Text(message['text'] +
                      //     '  from  ' +
                      //     message['sender']),
                    ],
                  ),
                )
              : Expanded(
                  child: Center(
                    child: Text(
                      'Itna sannata kyu hai bhai?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                      ),
                    ),
                  ),
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
