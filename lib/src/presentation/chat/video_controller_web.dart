import 'package:video_player/video_player.dart';

VideoPlayerController createVideoController(
  Uri uri, {
  VideoPlayerOptions? options,
}) => VideoPlayerController.networkUrl(uri, videoPlayerOptions: options);
