import 'dart:io';
import 'package:video_player/video_player.dart';

VideoPlayerController createVideoController(
  Uri uri, {
  VideoPlayerOptions? options,
}) => uri.scheme == 'file'
    ? VideoPlayerController.file(File.fromUri(uri), videoPlayerOptions: options)
    : VideoPlayerController.networkUrl(uri, videoPlayerOptions: options);
