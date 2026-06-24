import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionCheckService {
  static const _minVersionKey = 'min_required_version';

  // Returns true if the running app version meets the minimum required version.
  // Fails open (returns true) if Remote Config cannot be reached.
  Future<bool> isUpToDate() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await remoteConfig.setDefaults({_minVersionKey: '1.0.5'});
      await remoteConfig.fetchAndActivate();

      final minVersion = remoteConfig.getString(_minVersionKey);
      final packageInfo = await PackageInfo.fromPlatform();
      return !_isOlderThan(packageInfo.version, minVersion);
    } catch (_) {
      return true;
    }
  }

  // Returns true if [current] is strictly older than [minimum].
  bool _isOlderThan(String current, String minimum) {
    final c = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final m = minimum.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (int i = 0; i < m.length; i++) {
      final cv = i < c.length ? c[i] : 0;
      final mv = m[i];
      if (cv < mv) return true;
      if (cv > mv) return false;
    }
    return false;
  }
}
