import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import "package:flutter/material.dart";

enum ReplyState { replying, notReplying }

class MessageRepository extends ChangeNotifier {
  ReplyState _replyState = ReplyState.notReplying;
  ReplyState get replyState => _replyState;

  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void toggleReplyState() {
    if (_replyState == ReplyState.notReplying)
      _replyState = ReplyState.replying;
    else
      _replyState = ReplyState.notReplying;

    notifyListeners();
  }

  void setReplyState() {
    _replyState = ReplyState.replying;
    notifyListeners();
  }

  void unsetReplyState() {
    _replyState = ReplyState.notReplying;
    notifyListeners();
  }

  void sendImageChat(
      {required File image,
      required String senderUid,
      required String messageUid,
      String groupName = ''}) async {
    String gName = groupName != '' ? groupName : '__common_Group__';
    // if gropuName is empty, send to default group
    // TODO: implement groups
    if (groupName == '') {
      // upload photo to firebase storage

      Reference firebaseStorageRef =
          FirebaseStorage.instance.ref().child('chatImages').child(messageUid);

      UploadTask uploadTask = firebaseStorageRef.putFile(image);

      TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);
      String photoUrl = await taskSnapshot.ref.getDownloadURL();

      await _firestore.collection('messages').doc(messageUid).set({
        'groupId': gName,
        'messageUid': messageUid,
        'replyMessage': '',
        'sender': FirebaseAuth.instance.currentUser!.email,
        'senderUid': senderUid,
        'text': photoUrl, // TODO: refractor to photoUrl
        'time': DateTime.now().millisecondsSinceEpoch,
        'type': 'image',
      });
    }
  }
}
