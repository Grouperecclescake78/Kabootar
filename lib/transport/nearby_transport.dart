import 'dart:async';

import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';

import 'mesh_transport.dart';

/// [MeshTransport] backed by `flutter_nearby_connections`:
/// Google Nearby Connections on Android, MultipeerConnectivity on iOS.
///
/// It forms a P2P *cluster* (many-to-many) rather than a star, which is what an
/// epidemic mesh wants: every device both advertises and browses, and any two
/// in range auto-connect. Note the platform wall documented in the design -
/// this meshes Android<->Android and iOS<->iOS, but not across the two.
class NearbyTransport implements MeshTransport {
  NearbyTransport({required this.deviceName, this.serviceType = 'kabootar'});

  /// A human-ish name shown to peers during discovery. Kept short.
  final String deviceName;

  /// Bonjour/Nearby service type. Must be <= 15 chars, lowercase - this is the
  /// "network id" that scopes the mesh to the Kabootar community.
  final String serviceType;

  final NearbyService _nearby = NearbyService();
  TransportListener? _listener;

  StreamSubscription<dynamic>? _stateSub;
  StreamSubscription<dynamic>? _dataSub;

  /// deviceId -> its most recent known state, so we only fire connect/disconnect
  /// transitions once and auto-invite peers we have not yet linked.
  final Map<String, Device> _devices = <String, Device>{};

  @override
  Future<void> start({required TransportListener listener}) async {
    _listener = listener;

    await _nearby.init(
      serviceType: serviceType,
      deviceName: deviceName,
      strategy: Strategy.P2P_CLUSTER,
      callback: (bool isRunning) async {
        if (!isRunning) return;
        await _nearby.stopAdvertisingPeer();
        await _nearby.stopBrowsingForPeers();
        await _nearby.startAdvertisingPeer();
        await _nearby.startBrowsingForPeers();
      },
    );

    _stateSub = _nearby.stateChangedSubscription(callback: _onStateChanged);
    _dataSub = _nearby.dataReceivedSubscription(callback: _onDataReceived);
  }

  void _onStateChanged(List<Device> devices) {
    for (final Device device in devices) {
      final Device? previous = _devices[device.deviceId];
      _devices[device.deviceId] = device;

      switch (device.state) {
        case SessionState.notConnected:
          // Auto-connect: invite anyone in range we are not linked to. The
          // plugin de-duplicates repeated invitations, so this is safe to
          // fire on every sighting.
          _nearby.invitePeer(
            deviceID: device.deviceId,
            deviceName: device.deviceName,
          );
          if (previous?.state == SessionState.connected) {
            _listener?.onPeerDisconnected(device.deviceId);
          }
        case SessionState.connecting:
          break;
        case SessionState.connected:
          if (previous?.state != SessionState.connected) {
            _listener?.onPeerConnected(
              TransportPeer(
                deviceId: device.deviceId,
                deviceName: device.deviceName,
              ),
            );
          }
      }
    }
  }

  void _onDataReceived(dynamic data) {
    // Plugin hands us a map: { 'deviceId': ..., 'message': ... }.
    if (data is! Map<dynamic, dynamic>) return;
    final Object? deviceId = data['deviceId'];
    final Object? message = data['message'];
    if (deviceId is String && message is String) {
      _listener?.onPayload(deviceId, message);
    }
  }

  @override
  List<TransportPeer> get connectedPeers => _devices.values
      .where((Device d) => d.state == SessionState.connected)
      .map(
        (Device d) =>
            TransportPeer(deviceId: d.deviceId, deviceName: d.deviceName),
      )
      .toList(growable: false);

  @override
  Future<void> sendTo(String deviceId, String payload) async {
    final Device? device = _devices[deviceId];
    if (device == null || device.state != SessionState.connected) return;
    await _nearby.sendMessage(deviceId, payload);
  }

  @override
  Future<void> broadcast(String payload) async {
    for (final TransportPeer peer in connectedPeers) {
      await _nearby.sendMessage(peer.deviceId, payload);
    }
  }

  @override
  Future<void> stop() async {
    await _stateSub?.cancel();
    await _dataSub?.cancel();
    await _nearby.stopAdvertisingPeer();
    await _nearby.stopBrowsingForPeers();
    _devices.clear();
    _listener = null;
  }
}
