import 'dart:io';

import 'package:flash_chat_app/components/messageStream.dart';
import 'package:flash_chat_app/repository/messageRepository.dart';
import 'package:flash_chat_app/repository/themeRepository.dart';
import 'package:flash_chat_app/repository/userRepository.dart';
import 'package:flutter/material.dart';
import 'package:flash_chat_app/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';


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

    void unsetReply() {
      reply = false;
      replyMessage = '';
      replyTo = '';
      _messageRepository.unsetReplyState();
    }

    void addCodeRedRecord(value) {
      _firestore.collection('codered').add({
        "when": Timestamp.now(),
        "uidOfUser": FirebaseAuth.instance.currentUser!.uid,
        "codeUsed": value,
      });
    }

    void deleteAllMessages() {
      _firestore.collection('messages').get().then(
            (coll) => coll.docs.forEach(
              (doc) {
            doc.reference.delete();
          },
        ),
      );
    }

    int longHoldCount = 0;

    void coderedDialogController() {
      // reset longHoldCount after 1 minute
      Future.delayed(Duration(minutes: 1)).then((_) => longHoldCount = 0);
      longHoldCount++;
      print(longHoldCount);
      if (longHoldCount >= 5) {
        coderedDialog(context, deleteAllMessages, addCodeRedRecord);
        longHoldCount = 0;
      }
    }

    void scrollToLast() {
      _scrollController
          .animateTo(
        0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      )
          .catchError((onError) {
        print(onError);
      });
    }

    return WillPopScope(
      onWillPop: onWillPop,
      child: GestureDetector(
        // wipe out all messages on 5 time long hold on screen (to be used only in code red situation)
        // TODO: store code on db and fetch here
        onLongPress: coderedDialogController,

        // scroll to last on double tap anywhere
        onDoubleTap: scrollToLast,
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
                MessagesStream(scrollController: _scrollController),
                replyBubble(unsetReply),
                bottomSendMessageField(unsetReply, context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget bottomSendMessageField(void unsetReply(), BuildContext context) {
    String messageUid = Uuid().v4(); // generating a unique id
    final _messageRepository = MessageRepository();
    void sendImage(
        {required File image,
          required String senderUid,
          String groupName = ''}) {
      _messageRepository.sendImageChat(
          image: image, senderUid: senderUid, messageUid: messageUid);
    }

    return Container(
      decoration: kMessageContainerDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          IconButton(
              icon: Icon(Icons.image),
              onPressed: () async {
                File image;
                PickedFile? pickedFile = await ImagePicker().getImage(
                  source: ImageSource.gallery,
                  imageQuality: 70,
                  maxHeight: 1080,
                );
                if (pickedFile != null) {
                  image = File(pickedFile.path);

                  sendImage(
                    image: image,
                    senderUid: FirebaseAuth.instance.currentUser!.uid,
                    groupName: '',
                  );
                }
              }),
          Expanded(
            child: TextFormField(
              maxLines: 5,
              minLines: 1,
              controller: messageTextController,
              onChanged: (value) {
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
                _firestore.collection('messages').doc(messageUid).set(
                  {
                    'type': 'text', // text, image, location ....
                    'text': messageText.trim(),
                    'sender': loggedInUser.email,
                    'time': DateTime.now().millisecondsSinceEpoch,
                    'senderUid': FirebaseAuth.instance.currentUser!.uid,
                    'messageUid': messageUid,
                    'replyMessage': replyMessage, // text of the tagged message
                  },
                );
              }

              unsetReply();
            },
            child: Text(
              'Send',
              style: kSendButtonTextStyle,
            ),
          ),
        ],
      ),
    );
  }

  Future coderedDialog(BuildContext context, void deleteAllMessages(),
      void addCodeRedRecord(dynamic value)) {
    return showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 100),
          title: Text('CodeRed Dialog'),
          content: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Enter code'),
              TextField(
                onSubmitted: (value) {
                  if (value.toLowerCase() == 'codered') {
                    deleteAllMessages();

                    // record by whom codered was used and when and with what code
                    addCodeRedRecord(value);
                  }

                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget replyBubble(void unsetReply()) {
    return context.watch<MessageRepository>().replyState == ReplyState.replying
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
              messageUid: replyTo!,
              sender: '',
              senderUid: replyTo!,
              text: replyMessage,
              time: DateTime.now().millisecondsSinceEpoch,
              replyMessage: '',
              type: replyMessage.contains(
                  "https://firebasestorage.googleapis.com/v0/b/flash-chat-app-100a4.appspot.com/o/chatImages")
                  ? 'image'
                  : 'text',
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: IconButton(
              icon: Icon(Icons.cancel),
              onPressed: () {
                setState(() {
                  unsetReply();
                });
              },
            ),
          ),
        ],
      ),
    )
        : SizedBox();
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
    required this.type,
  });
  final String sender;
  final String text;
  final String senderUid;
  final String messageUid;
  final int time;
  final String replyMessage;
  final String type;

  @override
  _MessageBubbleState createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  @override
  Widget build(BuildContext context) {
    final _messageRepository = Provider.of<MessageRepository>(context);
    Size size = MediaQuery.of(context).size;
    Timestamp? time;
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(widget.time);
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
            replyTo = widget.senderUid;
            print(replyMessage);
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
                margin: EdgeInsets.only(bottom: 8.0),
                constraints: BoxConstraints(maxWidth: size.width * 0.7),
                padding: EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  border: Border(
                    left: widget.senderUid ==
                        FirebaseAuth.instance.currentUser!.uid
                        ? BorderSide(
                        color: Colors.green.shade800, width: 2)
                        : BorderSide.none,
                    right: widget.senderUid !=
                        FirebaseAuth.instance.currentUser!.uid
                        ? BorderSide(
                        color: Colors.green.shade800, width: 2)
                        : BorderSide.none,
                  ),
                ),
                child: widget.replyMessage.contains(
                    'https://firebasestorage.googleapis.com/v0/b/flash-chat-app-100a4.appspot.com/o/chatImages')
                    ? Container(
                  width: 100,
                  height: 100,
                  child: Image.network(widget.replyMessage),
                )
                    : Text(widget.replyMessage),
              )
                  : SizedBox(),
              widget.type == 'text'
                  ? Column(
                children: [
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
                      color: widget.senderUid ==
                          FirebaseAuth.instance.currentUser!.uid
                          ? Colors.blueAccent.shade700
                          : getColorByUid(uid: widget.senderUid),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: size.height * .015,
                            horizontal: size.width * .05),
                        child: Text(
                          widget.text,
                          style: TextStyle(
                              fontSize: size.width * .04,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  Text(DateFormat("hh:mm a").format(dateTime),
                    style: TextStyle(
                        fontSize: size.width * .028, color: Colors.white),
                  ),
                ],
              )
                  : GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => InteractiveViewer(
                        child: Image.network(widget.text),
                      )));
                },
                child: Container(
                  height: size.height * 0.3,
                  constraints: BoxConstraints(maxWidth: size.width * 0.7),
                  child: Image.network(
                    widget.text,
                    fit: BoxFit.cover,
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
