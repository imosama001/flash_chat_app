import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_chat_app/screens/chat_screen.dart';
import 'package:flutter/material.dart';

class MessagesStream extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController scrollController;

  MessagesStream({Key? key, required this.scrollController}) : super(key: key);
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
                  // TODO: implement with animated list view
                  child: ListView(
                    controller: scrollController,
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
                          type: messageList[i]['type'],
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
