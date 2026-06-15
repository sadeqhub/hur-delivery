import 'package:audioplayers/audioplayers.dart';
import '../utils/logger.dart';

/// Service to play audio notifications for new orders
class AudioNotificationService {
  static final AudioNotificationService _instance = AudioNotificationService._internal();
  factory AudioNotificationService() => _instance;
  AudioNotificationService._internal();

  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _isPlaying = false;
  static bool _initialized = false;

  /// Initialize the audio player (sets up completion listener)
  static void _initialize() {
    if (_initialized) return;
    
    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      Logger.d('✅ Notification sound finished playing');
    });
    
    _initialized = true;
  }

  /// Play the notification sound when a new order is received
  static Future<void> playNewOrderNotification() async {
    // Initialize on first use
    _initialize();
    
    // Prevent overlapping sounds
    if (_isPlaying) {
      Logger.d('🔇 Notification sound already playing, skipping...');
      return;
    }

    try {
      _isPlaying = true;
      Logger.d('🔔 Playing new order notification sound...');
      
      // Play the notification.mp3 from assets
      // Note: If the file doesn't exist, this will fail silently
      try {
        await _audioPlayer.play(AssetSource('notification.mp3'));
      } catch (e) {
        // If the asset file doesn't exist, log and reset playing state
        Logger.d('⚠️ Notification sound file not found. Please add assets/notification.mp3 to your assets folder.');
        Logger.d('   Error details: $e');
        _isPlaying = false;
      }
      
    } catch (e) {
      Logger.d('❌ Error playing notification sound: $e');
      _isPlaying = false;
    }
  }

  /// Stop the notification sound if playing
  static Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
    } catch (e) {
      Logger.d('❌ Error stopping notification sound: $e');
    }
  }

  /// Dispose the audio player (call on app termination)
  static void dispose() {
    _audioPlayer.dispose();
    _initialized = false;
  }
}

