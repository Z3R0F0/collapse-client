part of 'chat_screen.dart';

extension _ChatDraft on _ChatScreenState {
  void _initDraft() {
    _draftSession = _repository.sessionGeneration;
    var untouched = true;
    var previousText = _input.text;
    _repository
        .getTopic(widget.topicId)
        .then<void>((topic) {
          if (!mounted ||
              _repository.currentUserId != widget.userId ||
              _repository.sessionGeneration != _draftSession) {
            return;
          }
          _initialRead = topic?.readSeq ?? 0;
          if (untouched) {
            // Restoring is a read, not an edit which should be saved again.
            previousText = topic?.draft ?? '';
            _input.text = previousText;
          }
          _update(() {});
        })
        .catchError((Object _) {
          if (_repository.sessionGeneration == _draftSession) _error();
        });
    _input.addListener(() {
      if (_input.text == previousText) return;
      previousText = _input.text;
      _draftRevision++;
      untouched = false;
      _draftTimer?.cancel();
      _draftTimer = null;
      if (_suppressDraftSave) return;
      _draftTimer = Timer(const Duration(milliseconds: 400), _saveDraft);
    });
  }

  void _saveDraft() {
    _draftTimer?.cancel();
    _draftTimer = null;
    if (_repository.currentUserId != widget.userId ||
        _repository.sessionGeneration != _draftSession) {
      return;
    }
    // Capture text/scope before awaiting. Never read a disposed controller later.
    _repository.updateDraft(widget.topicId, _input.text).catchError((Object _) {
      if (_repository.sessionGeneration == _draftSession) _error();
    });
  }
}
