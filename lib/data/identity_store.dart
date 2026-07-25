import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/crypto/app_keys.dart';
import '../core/identity/identity.dart';

/// Reads and writes this device's persistent [Identity].
///
/// The `appId` is minted exactly once, on first launch, and then never changes
/// for the life of the install - it is the address every message is sent to.
class IdentityStore {
  IdentityStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _kAppId = 'studchat.appId';
  static const String _kName = 'studchat.name';
  static const String _kKeys = 'studchat.keys';
  static const Uuid _uuid = Uuid();

  static Future<IdentityStore> create() async =>
      IdentityStore(await SharedPreferences.getInstance());

  /// Whether onboarding has been completed (a display name is set).
  bool get isOnboarded => (_prefs.getString(_kName) ?? '').trim().isNotEmpty;

  /// Return the existing identity, minting a stable `appId` if this is the
  /// first launch. [name] may still be empty until onboarding sets it.
  Future<Identity> loadOrCreate() async {
    String? appId = _prefs.getString(_kAppId);
    if (appId == null || appId.isEmpty) {
      appId = _uuid.v4();
      await _prefs.setString(_kAppId, appId);
    }
    return Identity(appId: appId, name: _prefs.getString(_kName) ?? '');
  }

  Future<void> setName(String name) async {
    await _prefs.setString(_kName, name.trim());
  }

  /// Load this device's long-term encryption keys, minting and storing them on
  /// first launch. The private seeds live in app-private storage; they never
  /// leave the device.
  Future<AppKeys> loadOrCreateKeys() async {
    final String? stored = _prefs.getString(_kKeys);
    if (stored != null && stored.isNotEmpty) {
      try {
        return await AppKeys.fromSeeds(stored);
      } catch (_) {
        // Corrupt/incompatible material: fall through and mint fresh keys.
      }
    }
    final AppKeys keys = await AppKeys.generate();
    await _prefs.setString(_kKeys, await keys.exportSeeds());
    return keys;
  }
}
