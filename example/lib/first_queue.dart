import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_service_example/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class FirstQueue extends StatefulWidget {
  static const handlerNames = [
    'Audio Player',
    'Text-To-Speech',
  ];

  @override
  _FirstQueueState createState() => _FirstQueueState();
}

class _FirstQueueState extends State<FirstQueue> {
  @override
  void initState() {
    _setQueue();
    super.initState();
  }

  void _setQueue() async {
    await audioHandler.switchToHandler(0);
    const albumsRootId = 'new';
    final items = <String, List<MediaItem>>{
      AudioService.browsableRootId: const [
        MediaItem(
          id: albumsRootId,
          album: "",
          title: "Albums",
          playable: false,
        ),
      ],
      albumsRootId: [
        MediaItem(
          id: 'https://how-to-think-courses.s3.amazonaws.com/0qcdwev7xdtowx78cmp3axzfews2',
          album: "Science Friday",
          title: "A Salute To Head-Scratching Science",
          artist: "Science Friday and WNYC Studios",
          duration: const Duration(milliseconds: 5739820),
          artUri: Uri.parse('https://media.wnyc.org/i/1400/1400/l/80/1/ScienceFriday_WNYCStudios_1400.jpg'),
        ),
        MediaItem(
          id: 'https://how-to-think-courses.s3.amazonaws.com/jvnrwt86mq0jh0ynnjwg8xcbhsym',
          album: "Science Friday",
          title: "From Cat Rheology To Operatic Incompetence",
          artist: "Science Friday and WNYC Studios",
          duration: const Duration(milliseconds: 2856950),
          artUri: Uri.parse('https://media.wnyc.org/i/1400/1400/l/80/1/ScienceFriday_WNYCStudios_1400.jpg'),
        ),
      ],
    };

    // for (MediaItem mediaItem in items[albumsRootId]!) {
    //     _audioHandler.addQueueItem(mediaItem);
    // }
    //AudioService.queue!.items[albumsRootId]!);
    await audioHandler.updateQueue(items[albumsRootId]!);
    await audioHandler.skipToQueueItem(0);
    await Future.delayed(const Duration(seconds: 2), () => "2");
    var media = await audioHandler.queue.first;
    print("::::::::::::::::::::::::::::::::::::::::::");
    print(media!.first);
    print("::::::::::::::::::::::::::::::::::::::::::");
    // AudioServiceBackground.setMediaItem(items[albumsRootId]![0]);
    //await _audioHandler.playMediaItem(media.first);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Service Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Queue display/controls.
            StreamBuilder<QueueState>(
              stream: _queueStateStream,
              builder: (context, snapshot) {
                final queueState = snapshot.data;
                final queue = queueState?.queue ?? const [];
                final mediaItem = queueState?.mediaItem;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (queue.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(Icons.skip_previous),
                            iconSize: 64.0,
                            onPressed: mediaItem == queue.first ? null : audioHandler.skipToPrevious,
                          ),
                          IconButton(
                            icon: Icon(Icons.skip_next),
                            iconSize: 64.0,
                            onPressed: mediaItem == queue.last ? null : audioHandler.skipToNext,
                          ),
                        ],
                      ),
                    // Text(mediaItem.toString()),
                    // Text(":::::::::::::::::::::::::::::::::"),
                    // // queueState != null ? Text(queueState.mediaItem.toString()) : Text(snapshot.data.toString()),
                    // Text(":::::::::::::::::::::::::::::::::"),
                    // Text(queue.toString()),
                    if (mediaItem?.title != null) Text(mediaItem!.title),
                  ],
                );
              },
            ),
            // Play/pause/stop buttons.
            StreamBuilder<bool>(
              stream: audioHandler.playbackState.map((state) => state.playing).distinct(),
              builder: (context, snapshot) {
                final playing = snapshot.data ?? false;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (playing) pauseButton() else playButton(),
                    stopButton(),
                  ],
                );
              },
            ),
            // A seek bar.
            StreamBuilder<MediaState>(
              stream: _mediaStateStream,
              builder: (context, snapshot) {
                final mediaState = snapshot.data;
                return SeekBar(
                  duration: mediaState?.mediaItem?.duration ?? Duration.zero,
                  position: mediaState?.position ?? Duration.zero,
                  onChangeEnd: (newPosition) {
                    audioHandler.seek(newPosition);
                  },
                );
              },
            ),
            // Display the processing state.
            StreamBuilder<AudioProcessingState>(
              stream: audioHandler.playbackState.map((state) => state.processingState).distinct(),
              builder: (context, snapshot) {
                final processingState = snapshot.data ?? AudioProcessingState.idle;
                return Text("Processing state: ${describeEnum(processingState)}");
              },
            ),
            // Display the latest custom event.
            StreamBuilder<dynamic>(
              stream: audioHandler.customEvent,
              builder: (context, snapshot) {
                return Text("custom event: ${snapshot.data}");
              },
            ),
            // Display the notification click status.
            StreamBuilder<bool>(
              stream: AudioService.notificationClickEvent,
              builder: (context, snapshot) {
                return Text(
                  'Notification Click Status: ${snapshot.data}',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// A stream reporting the combined state of the current media item and its
  /// current position.
  Stream<MediaState> get _mediaStateStream => Rx.combineLatest2<MediaItem?, Duration, MediaState>(
      audioHandler.mediaItem,
      AudioService.getPositionStream(),
      (mediaItem, position) => MediaState(mediaItem, position));

  /// A stream reporting the combined state of the current queue and the current
  /// media item within that queue.
  Stream<QueueState> get _queueStateStream => Rx.combineLatest2<List<MediaItem>?, MediaItem?, QueueState>(
      audioHandler.queue, audioHandler.mediaItem, (queue, mediaItem) => QueueState(queue, mediaItem));

  ElevatedButton startButton(String label, VoidCallback onPressed) => ElevatedButton(
        onPressed: onPressed,
        child: Text(label),
      );

  IconButton playButton() => IconButton(
      icon: Icon(Icons.play_arrow),
      iconSize: 64.0,
      onPressed: () {
        // _audioHandler.switchToHandler(1);
        audioHandler.play();
      });

  IconButton pauseButton() => IconButton(
        icon: Icon(Icons.pause),
        iconSize: 64.0,
        onPressed: audioHandler.pause,
      );

  IconButton stopButton() => IconButton(
        icon: Icon(Icons.stop),
        iconSize: 64.0,
        onPressed: audioHandler.stop,
      );
}
