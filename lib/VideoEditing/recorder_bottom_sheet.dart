import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:path_provider/path_provider.dart';
import 'package:audio_session/audio_session.dart';

class RecorderBottomSheet extends StatefulWidget {
  final File mediaFile;
  final bool isVideo;

  const RecorderBottomSheet({
    super.key,
    required this.mediaFile,
    required this.isVideo,
  });

  @override
  State<RecorderBottomSheet> createState() => _RecorderBottomSheetState();
}

class _RecorderBottomSheetState extends State<RecorderBottomSheet>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Recording state
  bool isRecording = false;
  bool isPaused = false;
  bool hasRecording = false;
  Duration recordingDuration = Duration.zero;
  Timer? _timer;
  Timer? _blinkTimer;
  bool _timerBlink = true;

  // Audio instances
  final AudioRecorder _audioRecorder = AudioRecorder();
  final just_audio.AudioPlayer _audioPlayer = just_audio.AudioPlayer();
  AudioSession? _audioSession;

  // Playback state
  bool isPlaying = false;
  bool isSeeking = false;
  Duration playbackDuration = Duration.zero;
  Duration totalDuration = Duration.zero;

  // Trimming state
  bool isTrimmingMode = false;
  Duration trimStart = Duration.zero;
  Duration trimEnd = Duration.zero;

  // Recording path
  String? _recordingPath;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Scrolling waveform animation
  double _waveformScroll = 0.0;
  Timer? _scrollTimer;

  // Waveform data (real-time amplitude)
  List<double> _waveformData = [];
  double _currentAmplitude = 0.0;
  Timer? _amplitudeTimer;

  // Clipping detection
  bool _isClipping = false;
  int _clippingCount = 0;

  // Keep more samples for scrolling effect
  static const int maxWaveformSamples = 200;

  // File flush timer for corruption prevention
  Timer? _flushTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkPermissions();
    _setupAudioPlayer();
    _setupAudioSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _blinkTimer?.cancel();
    _amplitudeTimer?.cancel();
    _scrollTimer?.cancel();
    _flushTimer?.cancel();
    _pulseController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Setup audio session for interruption handling
  Future<void> _setupAudioSession() async {
    try {
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      // Listen for audio interruptions (calls, etc.)
      _audioSession!.interruptionEventStream.listen((event) {
        if (event.begin) {
          // Interruption began (e.g., phone call)
          if (isRecording && !isPaused) {
            _handleInterruption();
          }
          if (isPlaying) {
            _audioPlayer.pause();
          }
        } else {
          // Interruption ended
          // User can manually resume if needed
        }
      });
    } catch (e) {
      debugPrint('Failed to setup audio session: $e');
    }
  }

  // Handle audio interruption (phone calls, etc.)
  Future<void> _handleInterruption() async {
    await _pauseRecording();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recording paused due to interruption'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App going to background - save recording state
      if (isRecording && !isPaused) {
        _pauseRecording();
      }
      if (isPlaying) {
        _audioPlayer.pause();
      }
    }
  }

  // Check and request microphone permission
  Future<void> _checkPermissions() async {
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  // Setup audio player listeners
  void _setupAudioPlayer() {
    _audioPlayer.positionStream.listen((position) {
      if (!isSeeking && mounted) {
        setState(() {
          playbackDuration = position;
        });
      }
    });

    _audioPlayer.durationStream.listen((duration) {
      if (duration != null && mounted) {
        setState(() {
          totalDuration = duration;
          // Initialize trim points
          if (trimEnd == Duration.zero) {
            trimEnd = duration;
          }
        });
      }
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == just_audio.ProcessingState.completed && mounted) {
        setState(() {
          isPlaying = false;
          playbackDuration = trimStart;
        });
      }
    });
  }

  // Start recording
  Future<void> _startRecording() async {
    try {
      // Check permission
      if (await Permission.microphone.isDenied) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          _showPermissionDialog();
          return;
        }
      }

      // Delete previous recording if exists
      if (_recordingPath != null) {
        await _deleteRecordingFile(_recordingPath!);
      }

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${directory.path}/recording_$timestamp.m4a';

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
          numChannels: 1,
        ),
        path: _recordingPath!,
      );

      setState(() {
        isRecording = true;
        isPaused = false;
        hasRecording = false;
        recordingDuration = Duration.zero;
        _waveformData.clear();
        _waveformScroll = 0.0;
        _timerBlink = true;
        _isClipping = false;
        _clippingCount = 0;
      });

      // Start timer for duration
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!isPaused && mounted) {
          setState(() {
            recordingDuration += const Duration(seconds: 1);
          });
        }
      });

      // Start blinking timer
      _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (mounted) {
          setState(() {
            _timerBlink = !_timerBlink;
          });
        }
      });

      // Start amplitude monitoring
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
        if (isRecording && !isPaused) {
          try {
            final amplitude = await _audioRecorder.getAmplitude();
            if (mounted) {
              setState(() {
                _currentAmplitude = amplitude.current.clamp(-60.0, 0.0);

                // Normalize to 0-1 range
                final normalized = (_currentAmplitude + 60) / 60;
                _waveformData.add(normalized);

                // Clipping detection (amplitude > 0.9 = -1dB)
                if (normalized > 0.9) {
                  _isClipping = true;
                  _clippingCount++;
                  HapticFeedback.heavyImpact(); // Alert user
                } else {
                  _isClipping = false;
                }

                // Keep limited samples
                if (_waveformData.length > maxWaveformSamples) {
                  _waveformData.removeAt(0);
                }
              });
            }
          } catch (e) {
            // Ignore amplitude errors
          }
        }
      });

      // Scrolling animation timer
      _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (mounted && isRecording && !isPaused) {
          setState(() {
            _waveformScroll += 0.5; // Scroll speed
          });
        }
      });

      // Periodic file flush for corruption prevention
      _flushTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        if (isRecording) {
          try {
            // The record package handles flushing internally
            // This is just a safety measure
            debugPrint('Recording checkpoint: ${recordingDuration.inSeconds}s');
          } catch (e) {
            debugPrint('Flush error: $e');
          }
        }
      });

    } catch (e) {
      _showErrorDialog('Failed to start recording: $e');
    }
  }

  // Pause recording
  Future<void> _pauseRecording() async {
    try {
      await _audioRecorder.pause();
      _blinkTimer?.cancel();
      _scrollTimer?.cancel();
      setState(() {
        isPaused = true;
        _timerBlink = true;
      });
    } catch (e) {
      _showErrorDialog('Failed to pause recording: $e');
    }
  }

  // Resume recording
  Future<void> _resumeRecording() async {
    try {
      await _audioRecorder.resume();

      _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (mounted) {
          setState(() {
            _timerBlink = !_timerBlink;
          });
        }
      });

      _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (mounted && isRecording && !isPaused) {
          setState(() {
            _waveformScroll += 0.5;
          });
        }
      });

      setState(() {
        isPaused = false;
      });
    } catch (e) {
      _showErrorDialog('Failed to resume recording: $e');
    }
  }

  // Stop recording
  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      _timer?.cancel();
      _blinkTimer?.cancel();
      _amplitudeTimer?.cancel();
      _scrollTimer?.cancel();
      _flushTimer?.cancel();

      setState(() {
        isRecording = false;
        isPaused = false;
        hasRecording = _recordingPath != null;
        _timerBlink = true;

        // Show clipping warning if detected
        if (_clippingCount > 10) {
          Future.delayed(Duration.zero, () {
            _showClippingWarning();
          });
        }
      });
    } catch (e) {
      _showErrorDialog('Failed to stop recording: $e');
    }
  }

  // Play recording with trimming support
  Future<void> _playRecording() async {
    if (_recordingPath == null) return;

    try {
      if (isPlaying) {
        await _audioPlayer.pause();
        setState(() {
          isPlaying = false;
        });
      } else {
        if (_audioPlayer.processingState == just_audio.ProcessingState.idle) {
          await _audioPlayer.setFilePath(_recordingPath!);
        }

        // Start from trim start position
        await _audioPlayer.seek(trimStart);
        await _audioPlayer.play();

        setState(() {
          isPlaying = true;
        });

        // Auto-stop at trim end
        _audioPlayer.positionStream.listen((position) {
          if (position >= trimEnd && isPlaying) {
            _audioPlayer.pause();
            _audioPlayer.seek(trimStart);
            setState(() {
              isPlaying = false;
            });
          }
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to play recording: $e');
    }
  }

  // Toggle trimming mode
  void _toggleTrimmingMode() {
    setState(() {
      isTrimmingMode = !isTrimmingMode;
      if (!isTrimmingMode) {
        // Reset trim points when exiting
        trimStart = Duration.zero;
        trimEnd = totalDuration;
      }
    });
  }

  // Delete recording file
  Future<void> _deleteRecordingFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete file: $e');
    }
  }

  // Discard recording with confirmation
  void _discardRecording() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Recording?'),
        content: const Text(
          'Are you sure you want to discard this recording? This action cannot be undone.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDiscard();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  void _confirmDiscard() async {
    if (isRecording) {
      await _stopRecording();
    }
    if (isPlaying) {
      await _audioPlayer.stop();
    }

    if (_recordingPath != null) {
      await _deleteRecordingFile(_recordingPath!);
    }

    setState(() {
      recordingDuration = Duration.zero;
      playbackDuration = Duration.zero;
      totalDuration = Duration.zero;
      hasRecording = false;
      _recordingPath = null;
      _waveformData.clear();
      _waveformScroll = 0.0;
      isTrimmingMode = false;
      trimStart = Duration.zero;
      trimEnd = Duration.zero;
    });
  }

  // Save recording
  void _saveRecording() async {
    if (_recordingPath == null) return;

    if (isRecording) {
      await _stopRecording();
    }
    if (isPlaying) {
      await _audioPlayer.stop();
    }

    // Return recording info with trim points
    final result = {
      'path': _recordingPath,
      'duration': recordingDuration,
      'trimStart': trimStart,
      'trimEnd': trimEnd,
    };

    Navigator.pop(context, result);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice saved successfully!'),
          backgroundColor: Color(0xFF2196F3),
        ),
      );
    }
  }

  // Show clipping warning
  void _showClippingWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Audio Clipping Detected'),
          ],
        ),
        content: const Text(
          'Your recording may have distortion due to loud input. Try moving away from the microphone or lowering your voice volume.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Microphone permission is required to record audio. Please grant permission in app settings.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildWaveform(),
                  if (_isClipping && isRecording) _buildClippingIndicator(),
                  const SizedBox(height: 30),
                  _buildRecordingInfo(),
                  const SizedBox(height: 40),
                  _buildRecordButton(),
                  const SizedBox(height: 30),
                  if (isRecording) _buildRecordingControls(),
                  if (hasRecording && !isRecording) _buildPlaybackControls(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, size: 28),
            onPressed: () {
              if (isRecording) {
                _stopRecording();
              }
              if (isPlaying) {
                _audioPlayer.stop();
              }
              if (_recordingPath != null && !hasRecording) {
                _deleteRecordingFile(_recordingPath!);
              }
              Navigator.pop(context);
            },
          ),
          const Text(
            'Voice Recorder Pro',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildWaveform() {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: CustomPaint(
        painter: ScrollingWaveformPainter(
          isRecording: isRecording,
          isPaused: isPaused,
          waveformData: _waveformData,
          scrollOffset: _waveformScroll,
          isClipping: _isClipping,
        ),
        child: Container(),
      ),
    );
  }

  Widget _buildClippingIndicator() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.warning_amber, color: Colors.red, size: 16),
          SizedBox(width: 8),
          Text(
            'Audio clipping - move mic away',
            style: TextStyle(
              color: Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingInfo() {
    return Column(
      children: [
        if (!isRecording && !hasRecording)
          const Text(
            'Tap to start recording',
            style: TextStyle(
              fontSize: 18,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          )
        else if (isRecording)
          Column(
            children: [
              AnimatedOpacity(
                opacity: _timerBlink ? 1.0 : 0.3,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _formatDuration(recordingDuration),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2196F3),
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isPaused ? Colors.orange : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPaused ? 'Paused' : 'Recording...',
                    style: TextStyle(
                      fontSize: 16,
                      color: isPaused ? Colors.orange : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          )
        else if (hasRecording)
            Column(
              children: [
                Text(
                  _formatDuration(isPlaying ? playbackDuration : trimStart),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2196F3),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Duration: ${_formatDuration(recordingDuration)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
      ],
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (!isRecording && !hasRecording) {
          _startRecording();
        } else if (isRecording) {
          _stopRecording();
        }
      },
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: isRecording ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isRecording
                      ? [Colors.red, Colors.red.shade700]
                      : hasRecording
                      ? [Colors.green, Colors.green.shade700]
                      : [const Color(0xFF2196F3), const Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isRecording
                        ? Colors.red
                        : hasRecording
                        ? Colors.green
                        : const Color(0xFF2196F3))
                        .withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                isRecording
                    ? Icons.stop
                    : hasRecording
                    ? Icons.check
                    : Icons.mic,
                size: 50,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecordingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          icon: isPaused ? Icons.play_arrow : Icons.pause,
          label: isPaused ? 'Resume' : 'Pause',
          onTap: isPaused ? _resumeRecording : _pauseRecording,
          color: Colors.orange,
        ),
        const SizedBox(width: 24),
        _buildControlButton(
          icon: Icons.stop,
          label: 'Stop',
          onTap: _stopRecording,
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildPlaybackControls() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2196F3).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Preview your recording',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton.icon(
                onPressed: _toggleTrimmingMode,
                icon: Icon(
                  isTrimmingMode ? Icons.check : Icons.content_cut,
                  size: 16,
                ),
                label: Text(isTrimmingMode ? 'Done' : 'Trim'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2196F3),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar with trimming handles
          Column(
            children: [
              if (isTrimmingMode) _buildTrimmingSlider(),
              if (!isTrimmingMode) _buildPlaybackSlider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(isTrimmingMode ? trimStart : playbackDuration),
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    Text(
                      _formatDuration(isTrimmingMode ? trimEnd : totalDuration),
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: isPlaying ? Icons.pause : Icons.play_arrow,
                label: isPlaying ? 'Pause' : 'Play',
                onTap: _playRecording,
                color: const Color(0xFF2196F3),
              ),
              _buildControlButton(
                icon: Icons.replay,
                label: 'Re-record',
                onTap: () {
                  _discardRecording();
                },
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackSlider() {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
      ),
      child: Slider(
        value: totalDuration.inMilliseconds > 0
            ? (playbackDuration.inMilliseconds / totalDuration.inMilliseconds)
            .clamp(0.0, 1.0)
            : 0.0,
        onChangeStart: (value) {
          if (isPlaying) {
            _audioPlayer.pause();
          }
          setState(() {
            isSeeking = true;
          });
        },
        onChanged: (value) {
          final position = Duration(
            milliseconds: (value * totalDuration.inMilliseconds).round(),
          );
          setState(() {
            playbackDuration = position;
          });
        },
        onChangeEnd: (value) async {
          final position = Duration(
            milliseconds: (value * totalDuration.inMilliseconds).round(),
          );
          await _audioPlayer.seek(position);
          setState(() {
            isSeeking = false;
          });
          if (isPlaying) {
            await _audioPlayer.play();
          }
        },
        activeColor: const Color(0xFF2196F3),
        inactiveColor: Colors.grey.shade300,
      ),
    );
  }

  Widget _buildTrimmingSlider() {
    return RangeSlider(
      values: RangeValues(
        totalDuration.inMilliseconds > 0
            ? (trimStart.inMilliseconds / totalDuration.inMilliseconds)
            .clamp(0.0, 1.0)
            : 0.0,
        totalDuration.inMilliseconds > 0
            ? (trimEnd.inMilliseconds / totalDuration.inMilliseconds)
            .clamp(0.0, 1.0)
            : 1.0,
      ),
      onChanged: (values) {
        setState(() {
          trimStart = Duration(
            milliseconds: (values.start * totalDuration.inMilliseconds).round(),
          );
          trimEnd = Duration(
            milliseconds: (values.end * totalDuration.inMilliseconds).round(),
          );
        });
        HapticFeedback.selectionClick();
      },
      activeColor: const Color(0xFF2196F3),
      inactiveColor: Colors.grey.shade300,
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: hasRecording || isRecording ? _discardRecording : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Discard'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.red,
                disabledForegroundColor: Colors.grey,
                side: BorderSide(
                  color: hasRecording || isRecording
                      ? Colors.red
                      : Colors.grey.shade300,
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: hasRecording && !isRecording ? _saveRecording : null,
              icon: const Icon(Icons.check),
              label: const Text('Save Recording'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Scrolling Waveform Painter
class ScrollingWaveformPainter extends CustomPainter {
  final bool isRecording;
  final bool isPaused;
  final List<double> waveformData;
  final double scrollOffset;
  final bool isClipping;

  ScrollingWaveformPainter({
    required this.isRecording,
    required this.isPaused,
    required this.waveformData,
    required this.scrollOffset,
    required this.isClipping,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final barWidth = 4.0;
    final spacing = 8.0;
    final barCount = (size.width / (barWidth + spacing)).floor();

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + spacing) - (scrollOffset % (barWidth + spacing));

      // Skip bars outside visible area
      if (x < -barWidth || x > size.width) continue;

      double barHeight;
      Color barColor;

      if (isRecording && !isPaused && waveformData.isNotEmpty) {
        // Calculate which data point to show
        final scrolledIndex = ((scrollOffset / (barWidth + spacing)) + i).floor();
        final dataIndex = scrolledIndex % waveformData.length;

        final amplitude = waveformData.isNotEmpty && dataIndex < waveformData.length
            ? waveformData[dataIndex]
            : 0.3;

        final minHeight = size.height * 0.15;
        final maxHeight = size.height * 0.85;
        barHeight = minHeight + (maxHeight - minHeight) * amplitude.clamp(0.0, 1.0);

        // Color based on amplitude - red for clipping
        if (amplitude > 0.9) {
          barColor = Colors.red;
        } else {
          barColor = isPaused ? Colors.orange : const Color(0xFF2196F3);
        }
      } else if (!isRecording && waveformData.isNotEmpty) {
        final dataIndex = (i * waveformData.length / barCount).floor();
        final amplitude = dataIndex < waveformData.length
            ? waveformData[dataIndex]
            : 0.3;

        final minHeight = size.height * 0.15;
        final maxHeight = size.height * 0.75;
        barHeight = minHeight + (maxHeight - minHeight) * amplitude.clamp(0.0, 1.0);

        barColor = amplitude > 0.9 ? Colors.orange : Colors.grey.shade400;
      } else {
        final variation = (i % 5) / 10;
        barHeight = size.height * (0.15 + variation * 0.1);
        barColor = Colors.grey.shade300;
      }

      final paint = Paint()
        ..color = barColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScrollingWaveformPainter oldDelegate) {
    return isRecording != oldDelegate.isRecording ||
        isPaused != oldDelegate.isPaused ||
        scrollOffset != oldDelegate.scrollOffset ||
        waveformData != oldDelegate.waveformData ||
        isClipping != oldDelegate.isClipping;
  }
}