class AppSettings {
  const AppSettings({required this.serverUrl, required this.roomId});

  const AppSettings.empty() : serverUrl = '', roomId = '';

  final String serverUrl;
  final String roomId;

  bool get hasServerUrl => serverUrl.isNotEmpty;
  bool get hasRoomId => roomId.isNotEmpty;
  bool get isComplete => hasServerUrl && hasRoomId;
  String get roomLabel => hasRoomId ? roomId : 'Not Set';

  AppSettings copyWith({String? serverUrl, String? roomId}) {
    return AppSettings(
      serverUrl: serverUrl ?? this.serverUrl,
      roomId: roomId ?? this.roomId,
    );
  }
}
