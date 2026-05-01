import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/voice_recording_provider.dart';
import '../../../core/services/delivery_fee_calculator.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/localization/app_localizations.dart';
import '../screens/voice_library_screen.dart';
import '../screens/create_order_screen.dart';

class CreateVoiceOrderScreen extends StatefulWidget {
  final bool embedded;

  const CreateVoiceOrderScreen({super.key, this.embedded = false});

  @override
  State<CreateVoiceOrderScreen> createState() => _CreateVoiceOrderScreenState();
}

class _CreateVoiceOrderScreenState extends State<CreateVoiceOrderScreen>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isLoading = false;
  late AnimationController _pulseController;
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioPath;
  Duration? _duration;

  // Extracted data from voice
  String? _customerName;
  String? _customerPhone;
  String? _pickupAddress;
  String? _deliveryAddress;
  double? _pickupLatitude;
  double? _pickupLongitude;
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  final String _vehicleType = 'motorcycle';
  double? _totalAmount;
  double? _deliveryFee;
  String? _notes;
  String? _transcription;
  double? _confidenceScore;
  List<String>? _missingFields;
  List<dynamic>? _items;

  int _onlineDriversCount = 0;
  bool _checkingDrivers = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _checkPermissions();
    _checkOnlineDrivers();
  }

  Future<void> _checkOnlineDrivers() async {
    try {
      setState(() {
        _checkingDrivers = true;
      });

      final merchantId = Supabase.instance.client.auth.currentUser?.id;
      final merchantCityRow = merchantId == null
          ? null
          : await Supabase.instance.client
              .from('users')
              .select('city')
              .eq('id', merchantId)
              .maybeSingle();
      final merchantCity = (merchantCityRow?['city'] ?? '').toString();
      if (merchantCity.isEmpty) {
        if (mounted) {
          setState(() {
            _onlineDriversCount = 0;
            _checkingDrivers = false;
          });
        }
        return;
      }

      // Get only online drivers
      final onlineDrivers = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('role', 'driver')
          .eq('is_online', true)
          .eq('city', merchantCity);

      if (onlineDrivers.isEmpty) {
        if (mounted) {
          setState(() {
            _onlineDriversCount = 0;
            _checkingDrivers = false;
          });
        }
        return;
      }

      // Get driver IDs
      final driverIds = (onlineDrivers as List<dynamic>)
          .map((driver) => driver['id'] as String?)
          .whereType<String>()
          .toList();

      // Check for active orders
      final activeOrders = await Supabase.instance.client
          .from('orders')
          .select('driver_id')
          .inFilter('driver_id', driverIds)
          .inFilter('status', ['pending', 'assigned', 'accepted', 'on_the_way']);

      // Get drivers with active orders
      final busyDriverIds = (activeOrders as List<dynamic>)
          .map((order) => order['driver_id'] as String?)
          .whereType<String>()
          .toSet();

      // Calculate free drivers (online without active orders)
      final freeDriverCount =
          driverIds.where((id) => !busyDriverIds.contains(id)).length;

      if (mounted) {
        setState(() {
          _onlineDriversCount = freeDriverCount;
          _checkingDrivers = false;
        });
      }
    } catch (e) {
      print('❌ Error checking available drivers: $e');
      if (mounted) {
        setState(() {
          _checkingDrivers = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context).microphonePermissionRequired),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final headerGradient = LinearGradient(
      colors: [cs.primary, cs.primaryContainer],
    );

    final cardDecoration = BoxDecoration(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: cs.outlineVariant),
    );

    final surfaceCardDecoration = BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: cs.outlineVariant, width: 2),
    );

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(AppLocalizations.of(context).voiceOrder),
              centerTitle: true,
            ),
      body: ListView(
        padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.04),
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.06),
            decoration: BoxDecoration(
              gradient: headerGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isRecording
                          ? 1.0 + (_pulseController.value * 0.2)
                          : 1.0,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cs.onPrimary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isRecording
                              ? Icons.mic
                              : _isProcessing
                                  ? Icons.hourglass_empty
                                  : Icons.mic_none,
                          size: 64,
                          color: cs.onPrimary,
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Column(
                      children: [
                        Text(
                          _isRecording
                              ? loc.recording
                              : _isProcessing
                                  ? loc.processingAudio
                                  : loc.clickToStart,
                          style: TextStyle(
                            color: cs.onPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isProcessing ? loc.extractingData : loc.speakOrderDetails,
                          style: TextStyle(
                            color: cs.onPrimary.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: MediaQuery.sizeOf(context).height * 0.03),

          // Voice Instructions
          Container(
            padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.04),
            decoration: cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).howToUse,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final loc = AppLocalizations.of(context);
                    return Column(
                      children: [
                        _buildInstructionItem(loc.sayCustomerName),
                        _buildInstructionItem(loc.sayPhone),
                        _buildInstructionItem(loc.sayPickup),
                        _buildInstructionItem(loc.sayDelivery),
                        _buildInstructionItem(loc.sayAmount),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: MediaQuery.sizeOf(context).height * 0.03),

          // Voice Library Button
          OutlinedButton.icon(
            onPressed: _openVoiceLibrary,
            icon: const Icon(Icons.library_music, size: 20),
            label: Text(AppLocalizations.of(context).voiceLibrary),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.primary,
              side: BorderSide(color: cs.outline, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),

          // Start/Stop Recording Button
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.08,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _toggleVoiceRecording,
              icon: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                size: 32,
              ),
              label: Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context);
                  return Text(
                    _isRecording
                        ? loc.stopRecording
                        : _isProcessing
                            ? loc.processing
                            : loc.startVoiceRecording,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  );
                },
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording
                    ? cs.error
                    : _isProcessing
                        ? cs.surfaceContainerHighest
                        : cs.primary,
                foregroundColor: _isProcessing ? cs.onSurface : cs.onPrimary,
                disabledBackgroundColor: cs.surfaceContainerHighest,
                disabledForegroundColor: cs.onSurface.withOpacity(0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          SizedBox(height: MediaQuery.sizeOf(context).height * 0.03),

          // Extracted Data Preview
          if (_hasExtractedData()) ...[
            Container(
              padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.04),
              decoration: surfaceCardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: cs.tertiary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context).extractedData,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return Column(
                        children: [
                          if (_customerName != null)
                            _buildExtractedField(
                                loc.customerNameLabel, _customerName!, Icons.person),
                          if (_customerPhone != null)
                            _buildExtractedField(
                                loc.phoneLabel, _customerPhone!, Icons.phone),
                          if (_pickupAddress != null)
                            _buildExtractedField(
                                loc.pickupLabel, _pickupAddress!, Icons.location_on),
                          if (_deliveryAddress != null)
                            _buildExtractedField(
                                loc.deliveryLabel, _deliveryAddress!, Icons.location_on),
                          if (_totalAmount != null)
                            _buildExtractedField(
                              loc.amountLabel,
                              '${_totalAmount!.toStringAsFixed(0)} ${loc.currencySymbol}',
                              Icons.attach_money,
                            ),
                          if (_deliveryFee != null)
                            _buildExtractedField(
                              loc.deliveryFee,
                              '${_deliveryFee!.toStringAsFixed(0)} ${loc.currencySymbol}',
                              Icons.payments,
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.03),
            PrimaryButton(
              text: AppLocalizations.of(context).confirmCreateOrder,
              onPressed: _submitVoiceOrder,
              isLoading: _isLoading,
            ),
          ],

          SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),

          // Transcription (if available)
          if (_transcription != null) ...[
            Container(
              padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.04),
              decoration: cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.transcribe, color: cs.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context).transcription,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _transcription!,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (_confidenceScore != null) ...[
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final loc = AppLocalizations.of(context);
                        final scoreColor = _confidenceScore! > 0.8
                            ? cs.tertiary
                            : _confidenceScore! > 0.5
                                ? cs.secondary
                                : cs.error;

                        return Row(
                          children: [
                            Text(
                              loc.extractionAccuracy,
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${(_confidenceScore! * 100).toStringAsFixed(0)}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scoreColor,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
          ],

          // Missing Fields Warning (if any)
          if (_missingFields != null && _missingFields!.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.04),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.error),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: cs.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)
                          .missingFields(_missingFields!.join(', ')),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.02),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: context.themeTextSecondary,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.themeTextPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _hasExtractedData() {
    return _customerName != null ||
        _customerPhone != null ||
        _pickupAddress != null ||
        _deliveryAddress != null ||
        _totalAmount != null ||
        _deliveryFee != null;
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      // Stop recording
      await _stopRecording();
    } else {
      // Start recording
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      // Check for online drivers first
      await _checkOnlineDrivers();

      final loc = AppLocalizations.of(context);
      if (_onlineDriversCount == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.noDriversAvailableNow),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path =
            '${directory.path}/voice_order_${DateTime.now().millisecondsSinceEpoch}.mp4';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc, // AAC-LC: Standard AAC, widely compatible
            sampleRate: 16000, // Optimal for Whisper API
            numChannels: 1, // Mono audio
            bitRate: 96000, // Higher bitrate for better quality
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _audioPath = path;
        });

        print('🎤 Recording started: $path');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.microphonePermissionRequired),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error starting recording: $e');
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorStartingRecording(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        print('🎤 Recording stopped: $path');

        // Send to backend for transcription and extraction
        await _processVoiceOrder(path);
      }
    } catch (e) {
      print('❌ Error stopping recording: $e');
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorStoppingRecording(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openVoiceLibrary() async {
    final recordingId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const VoiceLibraryScreen(),
      ),
    );

    if (recordingId != null && mounted) {
      // Load the selected recording and reuse it
      await _reuseRecording(recordingId);
    }
  }

  Future<void> _reuseRecording(String recordingId) async {
    setState(() => _isProcessing = true);

    try {
      final provider = context.read<VoiceRecordingProvider>();
      final recording =
          provider.recordings.firstWhere((r) => r.id == recordingId);

      // If cached data exists, use it
      if (recording.hasExtractedData && recording.hasTranscription) {
        _populateFromCachedData(
            recording.transcription!, recording.extractedData!);

        // Mark as used
        await provider.updateRecording(
            recordingId: recordingId, markAsUsed: true);

        if (mounted) {
          final loc = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.recordingLoadedSuccess),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        // Download and reprocess
        final audioFile = await provider.downloadAudio(recording);
        if (audioFile != null) {
          await _processVoiceOrder(audioFile.path);
        }
      }
    } catch (e) {
      print('❌ Error reusing recording: $e');
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.recordingLoadFailed(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _populateFromCachedData(
      String transcription, Map<String, dynamic> extractedData) {
    // Normalize phone number: if 11 digits starting with 0, remove the leading zero
    String? phone = extractedData['customer_phone'] as String?;
    if (phone != null) {
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 11 && digits.startsWith('0')) {
        phone = digits.substring(1);
        print('📞 Normalized phone number: removed leading zero');
      }
    }
    
    setState(() {
      _transcription = transcription;
      _customerName = extractedData['customer_name'] as String?;
      _customerPhone = phone;
      _pickupAddress = extractedData['pickup_address'] as String?;
      _deliveryAddress = extractedData['delivery_address'] as String?;
      _deliveryFee = (extractedData['delivery_fee'] as num?)?.toDouble();
      _notes = extractedData['notes'] as String?;
      _confidenceScore =
          (extractedData['confidence_score'] as num?)?.toDouble();
      _missingFields = (extractedData['missing_fields'] as List?)?.cast<String>();
      _items = extractedData['items'] as List?;

      // Extract grand total
      if (extractedData['grand_total'] != null) {
        _totalAmount = (extractedData['grand_total'] as num).toDouble();
      }
    });
  }

  Future<void> _saveRecordingToStorage(
    String audioPath, {
    String? transcription,
    Map<String, dynamic>? extractedData,
  }) async {
    try {
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        print('⚠️ Audio file not found, skipping save');
        return;
      }

      final filename = audioPath.split('/').last;
      final fileStats = await audioFile.stat();

      final provider = context.read<VoiceRecordingProvider>();
      final recording = await provider.uploadRecording(
        audioFile: audioFile,
        filename: filename,
        durationSeconds: _duration?.inSeconds,
        transcription: transcription,
        extractedData: extractedData,
      );

      if (recording != null) {
        print('✅ Recording saved to storage: ${recording.id}');
      }
    } catch (e) {
      print('⚠️ Failed to save recording to storage: $e');
      // Don't show error to user - this is a background operation
    }
  }

  Future<void> _processVoiceOrder(String audioPath) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      print('📤 Sending audio to backend: $audioPath');

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConfig.voiceTranscribeUrl),
      );

      // Add authorization header for Supabase Edge Function
      request.headers['Authorization'] = 'Bearer ${Env.supabaseAnonKey}';

      // Add audio file
      request.files.add(await http.MultipartFile.fromPath(
        'audio',
        audioPath,
      ));

      // Set timeout
      var response = await request.send().timeout(
        AppConfig.apiTimeout,
        onTimeout: () {
          throw Exception('Request timeout - please try again');
        },
      );

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonData = json.decode(responseData);

        print('✅ Response received: ${jsonData.toString()}');

        // Normalize phone number: if 11 digits starting with 0, remove the leading zero
        String? phone = jsonData['customer_phone'] as String?;
        if (phone != null) {
          final digits = phone.replaceAll(RegExp(r'\D'), '');
          if (digits.length == 11 && digits.startsWith('0')) {
            phone = digits.substring(1);
            print('📞 Normalized phone number: removed leading zero');
          }
        }
        
        // Extract data from response
        final extractedData = {
          'customer_name': jsonData['customer_name'],
          'customer_phone': phone,
          'pickup_address': jsonData['pickup_address'],
          'delivery_address': jsonData['delivery_address'],
          'neighborhood': jsonData['neighborhood'], // Include neighborhood field for better matching
          'delivery_fee': jsonData['delivery_fee'],
          'grand_total': jsonData['grand_total'],
          'notes': jsonData['notes'],
          'transcription': jsonData['transcription'],
          'confidence_score': jsonData['confidence_score'],
          'missing_fields': jsonData['missing_fields'],
          'items': jsonData['items'],
        };

        print('✅ Extracted data: $extractedData');

        // Save recording to storage for future reuse
        await _saveRecordingToStorage(
          audioPath,
          transcription: jsonData['transcription'],
          extractedData: extractedData,
        );

        // Navigate to regular order creation form with pre-filled data
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateOrderScreen(
                initialData: extractedData,
              ),
            ),
          );
        }
      } else {
        final errorData = await response.stream.bytesToString();
        print('❌ Error response: $errorData');
        final loc = AppLocalizations.of(context);
        throw Exception(loc.audioProcessingFailed(response.statusCode));
      }
    } catch (e) {
      print('❌ Error processing voice order: $e');
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorText(e.toString())),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }

      // Clean up audio file
      try {
        final file = File(audioPath);
        if (await file.exists()) {
          await file.delete();
          print('🗑️ Cleaned up audio file');
        }
      } catch (e) {
        print('⚠️ Could not delete audio file: $e');
      }
    }
  }

  Future<void> _submitVoiceOrder() async {
    final loc = AppLocalizations.of(context);
    
    // Prevent order posting in demo mode
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن نشر الطلبات في وضع التجربة. يمكنك استكشاف شاشات إنشاء الطلبات ولكن لا يمكنك إرسالها.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    
    // Validate extracted data
    if (_customerName == null ||
        _customerPhone == null ||
        _pickupAddress == null ||
        _deliveryAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.incompleteData),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show confirmation if confidence is low
    if (_confidenceScore != null && _confidenceScore! < 0.7) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Text(loc.alert),
                ],
              );
            },
          ),
          content: Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return Text(
                loc.lowConfidence((_confidenceScore! * 100).toInt()),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context).continueAction),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isLoading = true);

    try {
      final merchantId = context.read<AuthProvider>().user!.id;

      // Note: Pickup and delivery coordinates should be geocoded from addresses
      // For now, using default Baghdad coordinates
      final pickupLat = _pickupLatitude ?? 33.3152;
      final pickupLng = _pickupLongitude ?? 44.3661;
      final deliveryLat = _deliveryLatitude ?? 33.3152;
      final deliveryLng = _deliveryLongitude ?? 44.3661;

      // Calculate total if not provided
      double finalTotal = _totalAmount ?? 0;
      
      // Calculate delivery fee based on distance if coordinates are available
      double finalDeliveryFee;
      if (_deliveryFee != null) {
        // Use provided fee if available
        finalDeliveryFee = _deliveryFee!;
      } else {
        // Calculate fee based on distance
      finalDeliveryFee = DeliveryFeeCalculator.calculateFeeFromCoordinates(
        pickupLat,
        pickupLng,
        deliveryLat,
        deliveryLng,
      );
      }
      print('💰 Calculated delivery fee from coordinates: $finalDeliveryFee IQD');
    

      // If items exist, calculate from items
      if (_items != null && _items!.isNotEmpty) {
        double itemsTotal = 0;
        for (var item in _items!) {
          final price = item['price']?.toDouble() ?? 0;
          final quantity = item['quantity'] ?? 1;
          itemsTotal += price * quantity;
        }
        if (itemsTotal > 0) {
          finalTotal = itemsTotal;
        }
      }

      // Customer phone is now optional - no validation needed
      if (_pickupAddress == null || _pickupAddress!.isEmpty) {
        throw Exception(loc.pickupAddressRequired);
      }
      if (_deliveryAddress == null || _deliveryAddress!.isEmpty) {
        throw Exception(loc.deliveryAddressRequired);
      }

      // Use default customer name if not provided
      final customerName =
          (_customerName == null || _customerName!.isEmpty)
              ? loc.customerNameFallback
              : _customerName!;

      await Supabase.instance.client.from('orders').insert({
        'merchant_id': merchantId,
        'customer_name': customerName,
        'customer_phone': _customerPhone!,
        'pickup_address': _pickupAddress!,
        'delivery_address': _deliveryAddress!,
        'pickup_latitude': pickupLat,
        'pickup_longitude': pickupLng,
        'delivery_latitude': deliveryLat,
        'delivery_longitude': deliveryLng,
        'vehicle_type': _vehicleType,
        'total_amount': finalTotal,
        'delivery_fee': finalDeliveryFee,
        'notes': _notes ??
            AppLocalizations.of(context)
                .voiceOrderNote(_transcription ?? ''),
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.orderCreatedSuccessVoice),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );

        // Pop back to dashboard
        context.pop();
      }
    } catch (e) {
      print('❌ Error submitting order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.orderCreateErrorVoice(e.toString())),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
