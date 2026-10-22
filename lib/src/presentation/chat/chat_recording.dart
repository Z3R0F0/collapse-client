part of 'chat_screen.dart';

extension _ChatRecording on _ChatScreenState {
  bool _canRecord(int operation) {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return mounted &&
        operation == _recordingOperation &&
        lifecycle != AppLifecycleState.hidden &&
        lifecycle != AppLifecycleState.paused &&
        lifecycle != AppLifecycleState.detached &&
        (ModalRoute.isCurrentOf(context) ?? true) &&
        ViewActivity.isActiveOf(context) &&
        !_cubit.isClosed &&
        _repository.currentUserId == widget.userId &&
        _repository.sessionGeneration == _draftSession;
  }

  void _cancelRecording({bool updateUi = true}) {
    _recordingOperation++;
    _recordingLimit?.cancel();
    _recordingLimit = null;
    final pending = _recording || _recordingPending;
    _recordingPending = false;
    _recordingStarted = null;
    if (_recording && updateUi && mounted) {
      _update(() => _recording = false);
    } else {
      _recording = false;
    }
    // AudioRecorder serializes native commands, so this also cancels a start
    // already in flight. Cancellation discards audio; stop would send it.
    if (pending) unawaited(_recorder.cancel().catchError((Object _) {}));
  }

  Future<void> _startRecording() async {
    if (_recording || _recordingPending || !_canRecord(_recordingOperation)) {
      return;
    }
    final operation = ++_recordingOperation;
    _recordingPending = true;
    try {
      final permitted = await _recorder.hasPermission();
      if (!mounted || !_canRecord(operation)) return;
      if (!permitted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.permissionDenied)));
        return;
      }
      final name = 'voice-${DateTime.now().millisecondsSinceEpoch}.wav';
      final path = kIsWeb
          ? name
          : '${(await getTemporaryDirectory()).path}/$name';
      if (!_canRecord(operation)) return;
      await _recorder.start(
        // One minute of mono PCM stays below the shared 10 MiB attachment limit.
        const RecordConfig(encoder: AudioEncoder.wav, numChannels: 1),
        path: path,
      );
      if (!_canRecord(operation)) {
        if (operation == _recordingOperation) _cancelRecording();
        return;
      }
      _recordingStarted = DateTime.now();
      _update(() => _recording = true);
      _recordingLimit = Timer(const Duration(minutes: 1), _stopRecording);
    } catch (_) {
      if (_canRecord(operation)) rethrow;
    } finally {
      if (operation == _recordingOperation) _recordingPending = false;
    }
  }

  Future<void> _stopRecording() async {
    if (!_recording || _recordingPending) return;
    final operation = _recordingOperation;
    final started = _recordingStarted!;
    _recordingPending = true;
    _recordingLimit?.cancel();
    _recordingLimit = null;
    try {
      final path = await _recorder.stop();
      if (!_canRecord(operation)) return;
      final duration = DateTime.now().difference(started).inMilliseconds;
      _update(() => _recording = false);
      _recordingStarted = null;
      if (path != null) {
        final bytes = await XFile(path).readAsBytes();
        if (!_canRecord(operation)) return;
        await _upload(
          bytes,
          'voice.wav',
          'audio/wav',
          'AU',
          duration: duration,
        );
      }
    } catch (_) {
      if (_canRecord(operation)) {
        _update(() => _recording = false);
        _error();
      }
    } finally {
      if (operation == _recordingOperation) _recordingPending = false;
    }
  }
}
