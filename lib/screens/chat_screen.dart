import 'package:flash_chat_app/repository/messageRepository.dart';
import 'package:flash_chat_app/repository/themeRepository.dart';
import 'package:flash_chat_app/repository/userRepository.dart';
import 'package:flutter/material.dart';
import 'package:flash_chat_app/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:swipe/swipe.dart';
import 'package:uuid/uuid.dart';

final _firestore = FirebaseFirestore.instance;
late final User loggedInUser;
late final User messageSender;
List<String> usersInChatUid = [];
final ScrollController _scrollController = ScrollController();
bool reply = false;
String? replyTo = '';
String replyMessage = '';

Color getColorByUid({required String uid}) {
  Color res = Colors.grey;
  if (usersInChatUid.isNotEmpty &&
      bubbleColor.length >= usersInChatUid.length &&
      usersInChatUid.contains(uid))
    res = bubbleColor[usersInChatUid.indexOf(uid)];
  return res;
}

void shuffleUsersList() {
  usersInChatUid.shuffle();
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
      shuffleUsersList();
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
    final _messageRepository = Provider.of<MessageRepository>(context);

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

    int longHoldCount = 0;

    return WillPopScope(
      onWillPop: onWillPop,
      child: GestureDetector(
        // wipe out all messages on 5 time long hold on screen (to be used only in code red situation)
        // TODO: store code on db and fetch here
        // TODO: add tracker: who used code red and when
        onLongPress: () {
          // reset longHoldCount after 1 minute
          Future.delayed(Duration(minutes: 1)).then((_) => longHoldCount = 0);
          longHoldCount++;
          print(longHoldCount);
          if (longHoldCount >= 5) {
            showDialog(
              context: context,
              builder: (dialogContext) {
                return AlertDialog(
                  insetPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 100),
                  title: Text('CodeRed Dialog'),
                  content: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Enter code'),
                      TextField(
                        onSubmitted: (value) {
                          if (value.toLowerCase() == 'codered') {
                            _firestore
                                .collection('messages')
                                .get()
                                .then((coll) => coll.docs.forEach((doc) {
                                      doc.reference.delete();
                                    }));

                            // record by whom codered was used and when and with what code
                            _firestore.collection('codered').add({
                              "when": Timestamp.now(),
                              "who": FirebaseAuth
                                  .instance.currentUser!.displayName,
                              "uidOfUser":
                                  FirebaseAuth.instance.currentUser!.uid,
                              "codeUsed": value,
                            });
                          }

                          Navigator.of(dialogContext).pop();
                        },
                      ),
                    ],
                  ),
                );
              },
            );
            longHoldCount = 0;
          }
        },

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
                context.watch<MessageRepository>().replyState ==
                        ReplyState.replying
                    ? Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.teal, width: 2),
                        ),
                        child: Stack(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(10),
                              child: MessageBubble(
                                messageUid: Uuid().v4(),
                                sender: '',
                                senderUid:
                                    FirebaseAuth.instance.currentUser!.uid,
                                text: replyMessage,
                                time: DateTime.now().millisecondsSinceEpoch,
                                replyMessage: '',
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: IconButton(
                                icon: Icon(Icons.cancel),
                                onPressed: () {
                                  setState(() {
                                    reply = false;
                                    replyMessage = '';
                                    replyTo = '';
                                    _messageRepository.unsetReplyState();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      )
                    : SizedBox(),
                Container(
                  decoration: kMessageContainerDecoration,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          maxLines: 5,
                          minLines: 1,
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
                                'replyMessage':
                                    replyMessage, // text of the tagged message
                              },
                            );
                          }

                          _messageRepository.unsetReplyState();
                          replyTo = '';
                          replyMessage = '';
                          reply = false;
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

class MessageBubble extends StatefulWidget {
  MessageBubble({
    required this.sender,
    required this.text,
    required this.senderUid,
    required this.messageUid,
    required this.time,
    required this.replyMessage,
  });
  final String sender;
  final String text;
  final String senderUid;
  final String messageUid;
  final int time;
  final String replyMessage;

  @override
  _MessageBubbleState createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  @override
  Widget build(BuildContext context) {
    final _messageRepository = Provider.of<MessageRepository>(context);
    Size size = MediaQuery.of(context).size;
    void deleteMessage({required String messageUid}) async {
      await _firestore.collection('messages').doc(messageUid).delete();
    }

    if (!usersInChatUid.contains(widget.senderUid)) {
      setState(() {
        usersInChatUid.add(widget.senderUid);
      });
    }

    bool isNotLate() {
      return DateTime.now()
              .subtract(Duration(hours: 2))
              .millisecondsSinceEpoch <=
          widget.time;
    }

    // Future<Map<String, dynamic>?> getReplyMessageDetails() async {
    //   Map<String, dynamic>? message;
    //   var snap =
    //       await _firestore.collection('messages').doc(widget.replyTo).get();
    //   message = snap.data();
    //   return message;
    // }

    // bool isReplyMessageLoaded = false;
    // Map<String, dynamic>? replyMessageDetail;

    // if (widget.replyTo != '') {
    //   getReplyMessageDetails().then((value) {
    //     setState(() {
    //       replyMessageDetail = value;
    //       isReplyMessageLoaded = true;
    //       print(value);
    //       print("*" * 100);
    //     });
    //   });
    // }

    return GestureDetector(
      onLongPress: () {
        if (widget.senderUid == FirebaseAuth.instance.currentUser!.uid &&
            isNotLate())
          showDialog(
            context: context,
            builder: (ctxt) => AlertDialog(
              actions: [
                TextButton(
                    onPressed: () {
                      deleteMessage(messageUid: widget.messageUid);
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
      child: GestureDetector(
        onHorizontalDragStart: (details) {
      setState(() {
              reply = true;
              replyMessage = widget.text;
              replyTo = widget.messageUid;
              _messageRepository.setReplyState();
            });    
        },
              child: Padding(
                padding: EdgeInsets.all(size.width * .02),
                child: Column(
                  crossAxisAlignment:
                      widget.senderUid == FirebaseAuth.instance.currentUser!.uid
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                  children: [
                    widget.replyMessage != ''
                        // reply message text above the message bubble
                        ? Container(
                            constraints: BoxConstraints(maxWidth: size.width * 0.7),
                            padding: EdgeInsets.all(4.0),
                            decoration: BoxDecoration(
                                border: Border(
                                    left: BorderSide(
                                        color: Colors.green.shade800, width: 2))),
                            child: Text(widget.replyMessage),
                          )
                        : SizedBox(),
                    // Text(sender, style: TextStyle(color: Colors.black54, fontSize: 12)),
                    Container(
                      constraints: BoxConstraints(maxWidth: size.width * 0.7),
                      child: Material(
                        elevation: size.width * .01,
                        borderRadius: BorderRadius.only(
                          topLeft: widget.senderUid ==
                                  FirebaseAuth.instance.currentUser!.uid
                              ? Radius.circular(size.height * .05)
                              : Radius.zero,
                          topRight: widget.senderUid !=
                                  FirebaseAuth.instance.currentUser!.uid
                              ? Radius.circular(size.height * .05)
                              : Radius.zero,
                          bottomLeft: Radius.circular(size.height * .05),
                          bottomRight: Radius.circular(size.height * .05),
                        ),
                        color:
                            widget.senderUid == FirebaseAuth.instance.currentUser!.uid
                                ? Colors.blueAccent.shade700
                                : getColorByUid(uid: widget.senderUid),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: size.height * .015,
                              horizontal: size.width * .05),
                          child: Text(
                            widget.text,
                            style: TextStyle(
                                fontSize: size.width * .04, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
                          replyMessage: messageList[i]['replyMessage'],
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
