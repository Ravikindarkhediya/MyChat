import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

class CallingService{

  final JitsiMeet jitsiMeet = JitsiMeet();

  void startCall(String receiverId) {
    // generate unique roomId
    final roomId = 'call_${DateTime.now().millisecondsSinceEpoch}';

    // join myself
    joinMeeting(roomId);

    // notify receiver through backend / push
    // sendPushToReceiver(receiverId, roomId);
  }

  void joinMeeting(String roomId, {bool isAudioOnly = false}) async {
    final options = JitsiMeetConferenceOptions(
      room: roomId,
      userInfo: JitsiMeetUserInfo(
        displayName: "Current User",
        email: "test@gmail.com",
      ),
      configOverrides: {
        'startWithVideoMuted': isAudioOnly,
      },
    );

    await jitsiMeet.join(options);
  }
}