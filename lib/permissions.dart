import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Request the runtime permissions the mesh transport needs.
///
/// Android's Nearby Connections requires Bluetooth + fine location (and, on
/// Android 13+, the nearby-Wi-Fi-devices permission) to scan and advertise.
/// iOS's Multipeer prompts for local-network access on its own, so there is
/// nothing to request here.
Future<void> requestMeshPermissions() async {
  if (!Platform.isAndroid) return;

  await <Permission>[
    Permission.bluetooth,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
    Permission.location,
    Permission.nearbyWifiDevices,
  ].request();
}
