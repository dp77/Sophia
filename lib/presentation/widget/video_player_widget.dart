import 'package:girlfriend/core/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:convert';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:girlfriend/utils/video_thumbnail_cache.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool playSound;
  final bool allowUserPause;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.playSound = true,
    this.allowUserPause = true,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  String? _localThumbnailPath;

  bool _isInitialized = false;
  bool _isLoading = true;
  bool _isPlaying = true;
  bool _showPlayIcon = false;

  static const String _cacheKey = 'video_cache_last_clear';
  static const String _videoCacheKey = 'cached_videos';

  bool _wasPlayingBeforeBackground = false;
  bool _hasHandledInitialVisibility = false;
  bool _userPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndClearCache();
    _initializeVideo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_isInitialized || _controller == null) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _wasPlayingBeforeBackground = _isPlaying;
        if (_isPlaying) {
          _controller!.pause();
        }
        break;
      case AppLifecycleState.resumed:
        // Only resume if the user did not manually pause the video
        if (_wasPlayingBeforeBackground && !_userPaused) {
          _controller!.play();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _checkAndClearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final lastClear = prefs.getString(_cacheKey);
    final today = DateTime.now().toIso8601String().split('T')[0];

    if (lastClear != today) {
      await _clearVideoCache();
      await prefs.setString(_cacheKey, today);
    }
  }

  Future<void> _clearVideoCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final directory = await getTemporaryDirectory();
      final videoDir = Directory('${directory.path}/cached_videos');

      if (await videoDir.exists()) {
        await videoDir.delete(recursive: true);
      }

      await prefs.remove(_videoCacheKey);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<String?> _getCachedVideoPath(String videoUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedVideos = prefs.getStringList(_videoCacheKey) ?? [];

      for (String cachedInfo in cachedVideos) {
        final Map<String, dynamic> info = json.decode(cachedInfo);
        if (info['url'] == videoUrl) {
          final file = File(info['path']);
          if (await file.exists()) {
            return info['path'];
          }
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
    return null;
  }

  Future<String> _cacheVideo(String videoUrl) async {
    try {
      final directory = await getTemporaryDirectory();
      final videoDir = Directory('${directory.path}/cached_videos');
      if (!await videoDir.exists()) {
        await videoDir.create(recursive: true);
      }

      final fileName = videoUrl.split('/').last.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_');
      final filePath = '${videoDir.path}/$fileName';
      final file = File(filePath);

      if (!await file.exists()) {
        // Download video
        final request = await HttpClient().getUrl(Uri.parse(videoUrl));
        final response = await request.close();
        final bytes = await consolidateHttpClientResponseBytes(response);
        await file.writeAsBytes(bytes);
      }

      // Save to cache registry
      final prefs = await SharedPreferences.getInstance();
      final cachedVideos = prefs.getStringList(_videoCacheKey) ?? [];
      final cacheInfo = {'url': videoUrl, 'path': filePath, 'timestamp': DateTime.now().millisecondsSinceEpoch};
      cachedVideos.add(json.encode(cacheInfo));
      await prefs.setStringList(_videoCacheKey, cachedVideos);

      return filePath;
    } catch (e) {
      // Return original URL if caching fails
      return videoUrl;
    }
  }

  Future<void> _initializeVideo() async {
    if (widget.videoUrl.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      String? cachedPath = await _getCachedVideoPath(widget.videoUrl);
      cachedPath ??= await _cacheVideo(widget.videoUrl);
      await _ensureLocalThumbnail(cachedPath);
      if (cachedPath != widget.videoUrl) {
        _controller = VideoPlayerController.file(File(cachedPath));
      } else {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      }

      await _controller!.initialize();
      if (!mounted) return;
      _controller!.addListener(_videoListener);
      await _controller!.setVolume(widget.playSound ? 1.0 : 0.0);
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
      // _controller!.play();
      _controller!.setLooping(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _ensureLocalThumbnail(String cachedPath) async {
    if ((widget.thumbnailUrl ?? '').isNotEmpty) return;
    if (_localThumbnailPath != null && _localThumbnailPath!.isNotEmpty) return;
    if (cachedPath.isEmpty) return;

    try {
      final outPath = await VideoThumbnailCache.getOrCreate(videoUrl: widget.videoUrl, cachedVideoPath: cachedPath);
      if (outPath == null || outPath.isEmpty) return;
      if (!mounted) return;
      setState(() => _localThumbnailPath = outPath);
    } catch (_) {}
  }

  void _videoListener() {
    if (_controller != null && mounted) {
      final isPlaying = _controller!.value.isPlaying;
      if (_isPlaying != isPlaying) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    }
  }

  void _onVideoTap() {
    if (_controller == null || !_isInitialized) return;
    if (_isPlaying) {
      _userPaused = true; // User explicitly paused
      _controller!.pause();
      setState(() => _showPlayIcon = true);
    } else {
      _userPaused = false; // User explicitly resumed
      _controller!.play();
      setState(() => _showPlayIcon = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumb = widget.thumbnailUrl ?? '';
    final hasNetworkThumb = thumb.startsWith('http://') || thumb.startsWith('https://');
    final hasFileThumb = !hasNetworkThumb && thumb.isNotEmpty;
    final hasLocalThumb = (_localThumbnailPath ?? '').isNotEmpty;
    if (_isLoading) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (hasNetworkThumb)
            Image.network(thumb, fit: BoxFit.cover, alignment: Alignment.center)
          else if (hasFileThumb)
            Image.file(
              File(thumb),
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, _, _) => Container(color: Colors.black),
            )
          else if (hasLocalThumb)
            Image.file(File(_localThumbnailPath!), fit: BoxFit.cover, alignment: Alignment.center)
          else
            Container(color: Colors.black),
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      );
    }

    if (!_isInitialized || _controller == null) {
      if (hasNetworkThumb) {
        return Image.network(thumb, fit: BoxFit.cover, alignment: Alignment.center);
      }
      if (hasFileThumb) {
        return Image.file(
          File(thumb),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, _, _) => Container(color: Colors.black),
        );
      }
      if (hasLocalThumb) {
        return Image.file(File(_localThumbnailPath!), fit: BoxFit.cover, alignment: Alignment.center);
      }
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Icon(Icons.play_circle_outline, color: Colors.white54, size: 34),
      );
    }

    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: (visibilityInfo) {
        final visiblePercentage = visibilityInfo.visibleFraction * 100;

        if (_controller == null || !_isInitialized) return;

        // Prevent first-frame incorrect autoplay
        if (!_hasHandledInitialVisibility) {
          _hasHandledInitialVisibility = true;

          if (visiblePercentage > 50) {
            // Only autoplay on first visibility if user has not manually paused
            if (!_userPaused) {
              _controller!.play();
            }
          } else {
            _controller!.pause();
          }
          return;
        }

        // Normal behavior: respect _userPaused before auto-playing
        if (visiblePercentage > 50) {
          if (!_controller!.value.isPlaying && !_userPaused) {
            _controller!.play();
          }
        } else {
          if (_controller!.value.isPlaying) {
            _controller!.pause();
          }
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
          if (widget.allowUserPause)
            GestureDetector(
              onTap: Haptics.wrap(_onVideoTap),
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _showPlayIcon ? 0.8 : 0.0,
                    duration: Duration(milliseconds: 300),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .3), shape: BoxShape.circle),
                      child: Icon(Icons.play_arrow, color: Colors.white, size: 40),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
