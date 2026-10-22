import 'dart:async';
import 'package:flutter/services.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

class FakeAudioPlatform extends JustAudioPlatform {
  final players = <FakeAudioPlayer>[];
  bool delayLoad = false;
  bool rejectPlay = false;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = FakeAudioPlayer(request.id, this);
    players.add(player);
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    await players
        .firstWhere((p) => p.id == request.id)
        .dispose(DisposeRequest());
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async => DisposeAllPlayersResponse();
}

class FakeAudioPlayer extends AudioPlayerPlatform {
  FakeAudioPlayer(super.id, this.platform);
  final FakeAudioPlatform platform;
  final events = StreamController<PlaybackEventMessage>();
  final loaded = Completer<void>();
  Completer<PlayResponse>? _play;
  int plays = 0, pauses = 0, seeks = 0;
  bool disposed = false;

  void event(ProcessingStateMessage state, {int? errorCode}) {
    if (disposed) return;
    events.add(
      PlaybackEventMessage(
        processingState: state,
        updatePosition: Duration.zero,
        updateTime: DateTime.now(),
        bufferedPosition: const Duration(seconds: 30),
        duration: const Duration(seconds: 30),
        currentIndex: 0,
        icyMetadata: null,
        androidAudioSessionId: null,
        errorCode: errorCode,
        errorMessage: errorCode == null ? null : 'Decoder failure',
      ),
    );
  }

  void complete() {
    event(ProcessingStateMessage.completed);
    _finishPlay();
  }

  void _finishPlay() {
    if (_play != null && !_play!.isCompleted) _play!.complete(PlayResponse());
  }

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => events.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    event(ProcessingStateMessage.loading);
    if (platform.delayLoad) await loaded.future;
    event(ProcessingStateMessage.ready);
    return LoadResponse(duration: const Duration(seconds: 30));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    plays++;
    if (platform.rejectPlay) {
      throw PlatformException(code: 'play_failed', message: 'Decoder failure');
    }
    _play = Completer<PlayResponse>();
    return _play!.future;
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    pauses++;
    _finishPlay();
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    seeks++;
    event(ProcessingStateMessage.ready);
    return SeekResponse();
  }

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    if (!disposed) {
      disposed = true;
      _finishPlay();
      await events.close();
    }
    return DisposeResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();
  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();
  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();
  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async => SetSkipSilenceResponse();
  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();
  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();
  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async => SetShuffleOrderResponse();
  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async => SetAndroidAudioAttributesResponse();
}
