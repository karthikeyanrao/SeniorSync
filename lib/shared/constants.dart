
class AppConstants {
  // Using adb reverse tcp:5000 tcp:5000 — tunnels phone's localhost to PC's localhost
  // This bypasses Windows Firewall issues with WiFi IP
  static const String baseUrl = "http://127.0.0.1:5000/api";
}
