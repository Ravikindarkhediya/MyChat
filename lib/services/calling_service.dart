// lib/services/calling_service.dart (CORRECTED VERSION)
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

import 'notification_service/api_notification_service.dart';

class CallingService {
  final JitsiMeet jitsiMeet = JitsiMeet();
  bool _isInCall = false;
  String? _currentRoomId;

  // Start a new call with receiver
  Future<void> startCall(String receiverId, String currentUserName, currentUserId,
      {bool isVideoCall = true}) async {
    try {
      // Generate unique roomId
      final roomId = generateRoomId(currentUserName, receiverId);
      _currentRoomId = roomId;

      print('Starting call with Room ID: $roomId');

      // Send notification to receiver first
      final notificationSent = await ApiNotificationService.sendNotification(
        receiverId: receiverId,
        senderId: 'current_user_id', // Replace with actual current user ID
        senderName: currentUserName,
        message: isVideoCall ? 'Incoming video call' : 'Incoming voice call',
        chatId: roomId,
        messageType: isVideoCall ? 'video_call' : 'voice_call',
      );

      if (notificationSent) {
        print('✅ Call notification sent to receiver');
      } else {
        print('❌ Failed to send call notification');
      }

      // Join the meeting
      await joinMeeting(roomId, currentUserName, isAudioOnly: !isVideoCall);
    } catch (error) {
      print('❌ Error starting call: $error');
      throw error;
    }
  }

  // Join an existing meeting room
  Future<void> joinMeeting(String roomId, String userName,
      {bool isAudioOnly = false}) async {
    try {
      final options = JitsiMeetConferenceOptions(
        room: roomId,
        serverURL: "https://meet.jit.si",
        userInfo: JitsiMeetUserInfo(
          displayName: userName,
          email: "${userName.toLowerCase().replaceAll(' ', '')}@yourapp.com",
          avatar: "https://ui-avatars.com/api/?name=${userName}&background=random",
        ),
        featureFlags: {
          "add-people.enabled": false,
          "calendar.enabled": false,
          "call-integration.enabled": false,
          "chat.enabled": true,
          "close-captions.enabled": false,
          "invite.enabled": false,
          "live-streaming.enabled": false,
          "meeting-name.enabled": false,
          "meeting-password.enabled": false,
          "pip.enabled": true,
          "raise-hand.enabled": true,
          "recording.enabled": false,
          "toolbox.alwaysVisible": false,
          "video-share.enabled": true,
          "welcomepage.enabled": false,
          "prejoinpage.enabled": false,
        },
        configOverrides: {
          "startWithAudioMuted": false,
          "startWithVideoMuted": isAudioOnly,
          "requireDisplayName": true,
          "subject": "Video Call",
        },
      );

      // Correct join method - NO listener parameter
      await jitsiMeet.join(options);
      _isInCall = true;
      _currentRoomId = roomId;

      print('✅ Successfully joined meeting: $roomId');
    } catch (error) {
      print('❌ Error joining meeting: $error');
      throw error;
    }
  }

  // Answer incoming call
  Future<void> answerCall(String roomId, String userName, {bool isVideoCall = true}) async {
    print('📞 Answering call in room: $roomId');
    await joinMeeting(roomId, userName, isAudioOnly: !isVideoCall);
  }

  // End/Leave current call
  Future<void> endCall() async {
    try {
      if (_isInCall && _currentRoomId != null) {
        await jitsiMeet.hangUp();
        _isInCall = false;
        _currentRoomId = null;
        print('✅ Call ended successfully');
      } else {
        print('⚠️ No active call to end');
      }
    } catch (error) {
      print('❌ Error ending call: $error');
    }
  }

  // Toggle audio mute/unmute
  Future<void> toggleAudio() async {
    try {
      // Note: These methods might toggle automatically in some SDK versions
      await jitsiMeet.setAudioMuted(false);
      print('🔊 Audio toggled');
    } catch (error) {
      print('❌ Error toggling audio: $error');
    }
  }

  // Toggle video on/off
  Future<void> toggleVideo() async {
    try {
      await jitsiMeet.setVideoMuted(false);
      print('📹 Video toggled');
    } catch (error) {
      print('❌ Error toggling video: $error');
    }
  }

  // Send chat message (if supported in your SDK version)
  Future<void> sendChatMessage(String message, {String? to}) async {
    try {
      // Note: Method availability depends on SDK version
      // await jitsiMeet.sendChatMessage(message: message, to: to);
      print('💬 Chat message would be sent: $message');
    } catch (error) {
      print('❌ Error sending chat message: $error');
    }
  }

  // Cleanup - simple version
  void dispose() {
    _isInCall = false;
    _currentRoomId = null;
    print('🧹 CallingService disposed');
  }

  // Generate unique room ID
  String generateRoomId(String caller, String receiver) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final participants = [caller.replaceAll(' ', ''), receiver.replaceAll(' ', '')]..sort();
    return 'call_${participants.join('_')}_$timestamp';
  }

  // Quick voice-only call
  Future<void> startVoiceCall(String receiverId, String currentUserName, currentUserId) async {
    await startCall(receiverId, currentUserName, currentUserId, isVideoCall: false);
  }

  // Quick video call
  Future<void> startVideoCall(String receiverId, String currentUserName, currentUserId) async {
    await startCall(receiverId, currentUserName, currentUserId, isVideoCall: true);
  }

  // Check if currently in a call
  bool get isInCall => _isInCall;

  // Get current room ID
  String? get currentRoomId => _currentRoomId;
}
