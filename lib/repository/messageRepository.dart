import "package:flutter/material.dart";

enum ReplyState { replying, notReplying }

class MessageRepository extends ChangeNotifier {
  ReplyState _replyState = ReplyState.notReplying;
  ReplyState get replyState => _replyState;

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
}
