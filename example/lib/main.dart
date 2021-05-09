import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_service_example/first_queue.dart';
import 'package:audio_service_example/secondary_queue.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

// You might want to provide this using dependency injection rather than a
// global variable.
late AudioHandler audioHandler;

/// Extension methods for our custom actions.
extension DemoAudioHandler on AudioHandler {
  Future<void> switchToHandler(int? index) async {
    if (index == null) return;
    await audioHandler.customAction('switchToHandler', <String, dynamic>{'index': index});
  }
}

Future<void> main() async {
  audioHandler = await AudioService.init(
    builder: () => LoggingAudioHandler(MainSwitchHandler([
      AudioPlayerHandler(),
      TextPlayerHandler(),
    ])),
    config: AudioServiceConfig(
      androidNotificationChannelName: 'Audio Service Demo',
      androidNotificationOngoing: true,
      androidEnableQueue: true,
    ),
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Service Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  static const handlerNames = [
    'Audio Player',
    'Text-To-Speech',
  ];

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
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
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (context) => FirstQueue()),
                );
              },
              child: Text("First Queue"),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (context) => SecondaryQueue()),
                );
              },
              child: Text("Second Queue"),
            ),
          ],
        ),
      ),
    );
  }

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

class QueueState {
  final List<MediaItem>? queue;
  final MediaItem? mediaItem;

  QueueState(this.queue, this.mediaItem);
}

class MediaState {
  final MediaItem? mediaItem;
  final Duration position;

  MediaState(this.mediaItem, this.position);
}

class SeekBar extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final ValueChanged<Duration>? onChanged;
  final ValueChanged<Duration>? onChangeEnd;

  SeekBar({
    required this.duration,
    required this.position,
    this.onChanged,
    this.onChangeEnd,
  });

  @override
  _SeekBarState createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragValue;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final value = min(
      _dragValue ?? widget.position.inMilliseconds.toDouble(),
      widget.duration.inMilliseconds.toDouble(),
    );
    if (_dragValue != null && !_dragging) {
      _dragValue = null;
    }
    return Stack(
      children: [
        Slider(
          min: 0.0,
          max: widget.duration.inMilliseconds.toDouble(),
          value: value,
          onChanged: (value) {
            if (!_dragging) {
              _dragging = true;
            }
            setState(() {
              _dragValue = value;
            });
            if (widget.onChanged != null) {
              widget.onChanged!(Duration(milliseconds: value.round()));
            }
          },
          onChangeEnd: (value) {
            if (widget.onChangeEnd != null) {
              widget.onChangeEnd!(Duration(milliseconds: value.round()));
            }
            _dragging = false;
          },
        ),
        Positioned(
          right: 16.0,
          bottom: 0.0,
          child: Text(
              RegExp(r'((^0*[1-9]\d*:)?\d{2}:\d{2})\.\d+$').firstMatch("$_remaining")?.group(1) ?? '$_remaining',
              style: Theme.of(context).textTheme.caption),
        ),
      ],
    );
  }

  Duration get _remaining => widget.duration - widget.position;
}

class CustomEvent {
  final int handlerIndex;

  CustomEvent(this.handlerIndex);
}

class MainSwitchHandler extends SwitchAudioHandler {
  final List<AudioHandler> handlers;
  @override
  BehaviorSubject<dynamic> customState = BehaviorSubject<dynamic>.seeded(CustomEvent(0));

  MainSwitchHandler(this.handlers) : super(handlers.first) {
    // Configure the app's audio category and attributes for speech.
    AudioSession.instance.then((session) {
      session.configure(AudioSessionConfiguration.speech());
    });
  }

  @override
  Future<dynamic> customAction(String name, Map<String, dynamic>? extras) async {
    switch (name) {
      case 'switchToHandler':
        stop();
        final index = extras!['index'] as int;
        inner = handlers[index];
        customState.add(CustomEvent(index));
        return null;
      default:
        return super.customAction(name, extras);
    }
  }
}

class LoggingAudioHandler extends CompositeAudioHandler {
  LoggingAudioHandler(AudioHandler inner) : super(inner) {
    playbackState.listen((state) async {
      queue.forEach((element) {
        _log('playbackState :::::::::::::::: changed: $element');
      });
      _log('playbackState changed: $state');
    });
    queue.listen((queue) {
      _log('queue changed: $queue');
    });
    queueTitle.listen((queueTitle) {
      _log('queueTitle changed: $queueTitle');
    });
    mediaItem.listen((mediaItem) {
      _log('mediaItem changed: $mediaItem');
    });
    ratingStyle.listen((ratingStyle) {
      _log('ratingStyle changed: $ratingStyle');
    });
    androidPlaybackInfo.listen((androidPlaybackInfo) {
      _log('androidPlaybackInfo changed: $androidPlaybackInfo');
    });
    customEvent.listen((dynamic customEventStream) {
      _log('customEvent changed: $customEventStream');
    });
    customState.listen((dynamic customState) {
      _log('customState changed: $customState');
    });
  }

  // TODO: Use logger. Use different log levels.
  void _log(String s) => print('----- LOG: $s');

  @override
  Future<void> prepare() {
    _log('prepare()');
    return super.prepare();
  }

  @override
  Future<void> prepareFromMediaId(String mediaId, [Map<String, dynamic>? extras]) {
    _log('prepareFromMediaId($mediaId, $extras)');
    return super.prepareFromMediaId(mediaId, extras);
  }

  @override
  Future<void> prepareFromSearch(String query, [Map<String, dynamic>? extras]) {
    _log('prepareFromSearch($query, $extras)');
    return super.prepareFromSearch(query, extras);
  }

  @override
  Future<void> prepareFromUri(Uri uri, [Map<String, dynamic>? extras]) {
    _log('prepareFromSearch($uri, $extras)');
    return super.prepareFromUri(uri, extras);
  }

  @override
  Future<void> play() {
    _log('play()');
    return super.play();
  }

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) {
    _log('playFromMediaId($mediaId, $extras)');
    return super.playFromMediaId(mediaId, extras);
  }

  @override
  Future<void> playFromSearch(String query, [Map<String, dynamic>? extras]) {
    _log('playFromSearch($query, $extras)');
    return super.playFromSearch(query, extras);
  }

  @override
  Future<void> playFromUri(Uri uri, [Map<String, dynamic>? extras]) {
    _log('playFromUri($uri, $extras)');
    return super.playFromUri(uri, extras);
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) {
    _log('playMediaItem($mediaItem)');
    return super.playMediaItem(mediaItem);
  }

  @override
  Future<void> pause() {
    _log('pause()');
    return super.pause();
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) {
    _log('click($button)');
    return super.click(button);
  }

  @override
  Future<void> stop() {
    _log('stop()');
    return super.stop();
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) {
    _log('addQueueItem($mediaItem)');
    return super.addQueueItem(mediaItem);
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) {
    _log('addQueueItems($mediaItems)');
    return super.addQueueItems(mediaItems);
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) {
    _log('insertQueueItem($index, $mediaItem)');
    return super.insertQueueItem(index, mediaItem);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) {
    _log('updateQueue($queue)');
    return super.updateQueue(queue);
  }

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) {
    _log('updateMediaItem($mediaItem)');
    return super.updateMediaItem(mediaItem);
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) {
    _log('removeQueueItem($mediaItem)');
    return super.removeQueueItem(mediaItem);
  }

  @override
  Future<void> removeQueueItemAt(int index) {
    _log('removeQueueItemAt($index)');
    return super.removeQueueItemAt(index);
  }

  @override
  Future<void> skipToNext() {
    _log('skipToNext()');
    return super.skipToNext();
  }

  @override
  Future<void> skipToPrevious() {
    _log('skipToPrevious()');
    return super.skipToPrevious();
  }

  @override
  Future<void> fastForward() {
    _log('fastForward()');
    return super.fastForward();
  }

  @override
  Future<void> rewind() {
    _log('rewind()');
    return super.rewind();
  }

  @override
  Future<void> skipToQueueItem(int index) {
    _log('skipToQueueItem($index)');
    return super.skipToQueueItem(index);
  }

  @override
  Future<void> seek(Duration position) {
    _log('seek($position)');
    return super.seek(position);
  }

  @override
  Future<void> setRating(Rating rating, Map<String, dynamic>? extras) {
    _log('setRating($rating, $extras)');
    return super.setRating(rating, extras);
  }

  @override
  Future<void> setCaptioningEnabled(bool enabled) {
    _log('setCaptioningEnabled($enabled)');
    return super.setCaptioningEnabled(enabled);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) {
    _log('setRepeatMode($repeatMode)');
    return super.setRepeatMode(repeatMode);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) {
    _log('setShuffleMode($shuffleMode)');
    return super.setShuffleMode(shuffleMode);
  }

  @override
  Future<void> seekBackward(bool begin) {
    _log('seekBackward($begin)');
    return super.seekBackward(begin);
  }

  @override
  Future<void> seekForward(bool begin) {
    _log('seekForward($begin)');
    return super.seekForward(begin);
  }

  @override
  Future<void> setSpeed(double speed) {
    _log('setSpeed($speed)');
    return super.setSpeed(speed);
  }

  @override
  Future<dynamic> customAction(String name, Map<String, dynamic>? extras) async {
    _log('customAction($name, extras)');
    final dynamic result = await super.customAction(name, extras);
    _log('customAction -> $result');
    return result;
  }

  @override
  Future<void> onTaskRemoved() {
    _log('onTaskRemoved()');
    return super.onTaskRemoved();
  }

  @override
  Future<void> onNotificationDeleted() {
    _log('onNotificationDeleted()');
    return super.onNotificationDeleted();
  }

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic>? options]) async {
    _log('getChildren($parentMediaId, $options)');
    final result = await super.getChildren(parentMediaId, options);
    _log('getChildren -> $result');
    return result;
  }

  @override
  ValueStream<Map<String, dynamic>?> subscribeToChildren(String parentMediaId) {
    _log('subscribeToChildren($parentMediaId)');
    final result = super.subscribeToChildren(parentMediaId);
    result.listen((options) {
      _log('$parentMediaId children changed with options $options');
    });
    return result;
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    _log('getMediaItem($mediaId)');
    final result = await super.getMediaItem(mediaId);
    _log('getMediaItem -> $result');
    return result;
  }

  @override
  Future<List<MediaItem>> search(String query, [Map<String, dynamic>? extras]) async {
    _log('search($query, $extras)');
    final result = await super.search(query, extras);
    _log('search -> $result');
    return result;
  }

  @override
  Future<void> androidSetRemoteVolume(int volumeIndex) {
    _log('androidSetRemoteVolume($volumeIndex)');
    return super.androidSetRemoteVolume(volumeIndex);
  }

  @override
  Future<void> androidAdjustRemoteVolume(AndroidVolumeDirection direction) {
    _log('androidAdjustRemoteVolume($direction)');
    return super.androidAdjustRemoteVolume(direction);
  }
}

/// An [AudioHandler] for playing a list of podcast episodes.
class AudioPlayerHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  // ignore: close_sinks
  final BehaviorSubject<List<MediaItem>> _recentSubject = BehaviorSubject<List<MediaItem>>();
  //final _mediaLibrary = MediaLibrary();
  final _player = AudioPlayer();

  int? get index => _player.currentIndex;

  AudioPlayerHandler() {
    _init();
  }

  Future<void> _init() async {
    // Load and broadcast the queue
    //queue.add(_mediaLibrary.items[MediaLibrary.albumsRootId]);
    // For Android 11, record the most recent item so it can be resumed.
    mediaItem.whereType<MediaItem>().listen((item) => _recentSubject.add([item]));
    // Broadcast media item changes.
    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value!.isNotEmpty) mediaItem.add(queue.value![index]);
    });
    // Propagate all events from the audio player to AudioService clients.
    _player.playbackEventStream.listen(_broadcastState);
    // In this example, the service stops when reaching the end.
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) stop();
    });
    /*try {
      print("### _player.load 1");
      // After a cold restart (on Android), _player.load jumps straight from
      // the loading state to the completed state. Inserting a delay makes it
      // work. Not sure why!

      await Future.delayed(const Duration(seconds: 2), () => "2");
      //await Future.delayed(Duration(seconds: 2)); // magic delay
      await _player.setAudioSource(ConcatenatingAudioSource(
        children: queue.value!
            .map((item) => AudioSource.uri(Uri.parse(item.id)))
            .toList(),
      ));
      print("### loaded");
    } catch (e) {
      print("Error: $e");
    }*/
  }

  // @override
  // Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic>? options]) async {
  //   switch (parentMediaId) {
  //     case AudioService.recentRootId:
  //       // When the user resumes a media session, tell the system what the most
  //       // recently played item was.
  //       print("### get recent children: ${_recentSubject.value}:");
  //       return _recentSubject.value ?? [];
  //     default:
  //       // Allow client to browse the media library.
  //       print("### get $parentMediaId children: ${_mediaLibrary.items[parentMediaId]}:");
  //       return _mediaLibrary.items[parentMediaId]!;
  //   }
  // }
  //
  // @override
  // ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) {
  //   switch (parentMediaId) {
  //     case AudioService.recentRootId:
  //       return _recentSubject.map((_) => <String, dynamic>{});
  //     default:
  //       return Stream.value(_mediaLibrary.items[parentMediaId]).map((_) => <String, dynamic>{})
  //           as ValueStream<Map<String, dynamic>>;
  //   }
  // }

  @override
  Future<void> updateQueue(List<MediaItem> queue1) async {
    try {
      print("### _player.load 1");
      // After a cold restart (on Android), _player.load jumps straight from
      // the loading state to the completed state. Inserting a delay makes it
      // work. Not sure why!

      //await Future.delayed(Duration(seconds: 2)); // magic delay
      await _player.setAudioSource(ConcatenatingAudioSource(
        children: queue1.map((item) => AudioSource.uri(Uri.parse(item.id))).toList(),
      ));
      print("### loaded");
    } catch (e) {
      print("Error: $e");
    }
    return super.updateQueue(queue1);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    // Then default implementations of skipToNext and skipToPrevious provided by
    // the [QueueHandler] mixin will delegate to this method.
    if (index < 0 || index >= queue.value!.length) return;
    // This jumps to the beginning of the queue item at newIndex.
    _player.seek(Duration.zero, index: index);
    // Demonstrate custom events.
    customEventSubject.add('skip to $index');
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  /// Broadcasts the current state to all clients.
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value!.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }
}

/// Provides access to a library of media items. In your app, this could come
/// from a database or web service.
class MediaLibrary {
  static const albumsRootId = 'albums';

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
}

/*class MediaLibrary {
  static const albumsRootId = 'albums';

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
        id: 'https://s3.amazonaws.com/scifri-episodes/scifri20181123-episode.mp3',
        album: "Science Friday",
        title: "A Salute To Head-Scratching Science",
        artist: "Science Friday and WNYC Studios",
        duration: const Duration(milliseconds: 5739820),
        artUri: Uri.parse(
            'https://media.wnyc.org/i/1400/1400/l/80/1/ScienceFriday_WNYCStudios_1400.jpg'),
      ),
      MediaItem(
        id: 'https://s3.amazonaws.com/scifri-episodes/scifri20181123-episode.mp3',
        album: "Science Friday",
        title: "From Cat Rheology To Operatic Incompetence",
        artist: "Science Friday and WNYC Studios",
        duration: const Duration(milliseconds: 2856950),
        artUri: Uri.parse(
            'https://media.wnyc.org/i/1400/1400/l/80/1/ScienceFriday_WNYCStudios_1400.jpg'),
      ),
    ],
  };
}*/

/// This task defines logic for speaking a sequence of numbers using
/// text-to-speech.

class TextPlayerHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  // ignore: close_sinks
  final BehaviorSubject<List<MediaItem>> _recentSubject = BehaviorSubject<List<MediaItem>>();
  //final _mediaLibrary = MediaLibrary();
  final _player = AudioPlayer();

  int? get index => _player.currentIndex;

  TextPlayerHandler() {
    _init();
  }

  Future<void> _init() async {
    // Load and broadcast the queue
    //queue.add(_mediaLibrary.items[MediaLibrary.albumsRootId]);
    // For Android 11, record the most recent item so it can be resumed.
    mediaItem.whereType<MediaItem>().listen((item) => _recentSubject.add([item]));
    // Broadcast media item changes.
    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value!.isNotEmpty) mediaItem.add(queue.value![index]);
    });
    // Propagate all events from the audio player to AudioService clients.
    _player.playbackEventStream.listen(_broadcastState);
    // In this example, the service stops when reaching the end.
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) stop();
    });
    /*try {
      print("### _player.load 2");
      // After a cold restart (on Android), _player.load jumps straight from
      // the loading state to the completed state. Inserting a delay makes it
      // work. Not sure why!
      await Future.delayed(const Duration(seconds: 2), () => "2");
      await _player.setAudioSource(ConcatenatingAudioSource(
        children: queue.value!
            .map((item) => AudioSource.uri(Uri.parse(item.id)))
            .toList(),
      ));
      print("### loaded");
    } catch (e) {
      print("Error: $e");
    }*/
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue1) async {
    try {
      print("### _player.load 2");
      // After a cold restart (on Android), _player.load jumps straight from
      // the loading state to the completed state. Inserting a delay makes it
      // work. Not sure why!
      //await Future.delayed(const Duration(seconds: 2), () => "2");
      await _player.setAudioSource(ConcatenatingAudioSource(
        children: queue1.map((item) => AudioSource.uri(Uri.parse(item.id))).toList(),
      ));
      print("### loaded");
    } catch (e) {
      print("Error: $e");
    }
    return super.updateQueue(queue1);
  }

  // @override
  // Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic>? options]) async {
  //   switch (parentMediaId) {
  //     case AudioService.recentRootId:
  //       // When the user resumes a media session, tell the system what the most
  //       // recently played item was.
  //       print("### get recent children: ${_recentSubject.value}:");
  //       return _recentSubject.value ?? [];
  //     default:
  //       // Allow client to browse the media library.
  //       // print("### get $parentMediaId children: ${_mediaLibrary.items[parentMediaId]}:");
  //       return _recentSubject.value ?? [];
  //   }
  // }
  //
  // @override
  // ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) {
  //   switch (parentMediaId) {
  //     case AudioService.recentRootId:
  //       return _recentSubject.map((_) => <String, dynamic>{});
  //     default:
  //       return _recentSubject.map((_) => <String, dynamic>{});
  //   }
  // }

  @override
  Future<void> skipToQueueItem(int index) async {
    // Then default implementations of skipToNext and skipToPrevious provided by
    // the [QueueHandler] mixin will delegate to this method.
    if (index < 0 || index >= queue.value!.length) return;
    // This jumps to the beginning of the queue item at newIndex.
    _player.seek(Duration.zero, index: index);
    // Demonstrate custom events.
    customEventSubject.add('skip to $index');
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  /// Broadcasts the current state to all clients.
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value!.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }
}

/// An object that performs interruptable sleep.
class Sleeper {
  Completer<void>? _blockingCompleter;

  /// Sleep for a duration. If sleep is interrupted, a
  /// [SleeperInterruptedException] will be thrown.
  Future<void> sleep([Duration? duration]) async {
    _blockingCompleter = Completer();
    if (duration != null) {
      await Future.any<void>([Future.delayed(duration), _blockingCompleter!.future]);
    } else {
      await _blockingCompleter!.future;
    }
    final interrupted = _blockingCompleter!.isCompleted;
    _blockingCompleter = null;
    if (interrupted) {
      throw SleeperInterruptedException();
    }
  }

  /// Interrupt any sleep that's underway.
  void interrupt() {
    if (_blockingCompleter?.isCompleted == false) {
      _blockingCompleter!.complete();
    }
  }
}

class SleeperInterruptedException {}

/// A wrapper around FlutterTts that makes it easier to wait for speech to
/// complete.
class Tts {
  final FlutterTts _flutterTts = FlutterTts();
  Completer<void>? _speechCompleter;
  bool _interruptRequested = false;
  bool _playing = false;

  Tts() {
    _flutterTts.setCompletionHandler(() {
      _speechCompleter?.complete();
    });
  }

  bool get playing => _playing;

  Future<void> speak(String text) async {
    _playing = true;
    if (!_interruptRequested) {
      _speechCompleter = Completer();
      await _flutterTts.speak(text);
      await _speechCompleter!.future;
      _speechCompleter = null;
    }
    _playing = false;
    if (_interruptRequested) {
      _interruptRequested = false;
      throw TtsInterruptedException();
    }
  }

  Future<void> stop() async {
    if (_playing) {
      await _flutterTts.stop();
      _speechCompleter?.complete();
    }
  }

  void interrupt() {
    if (_playing) {
      _interruptRequested = true;
      stop();
    }
  }
}

class TtsInterruptedException {}
