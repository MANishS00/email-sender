import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionScreen extends StatefulWidget {
  const VersionScreen({super.key});

  @override
  State<VersionScreen> createState() => _VersionScreenState();
}

class _VersionScreenState extends State<VersionScreen> {
  late Future<String> _versionFuture;

  @override
  void initState() {
    super.initState();
    _versionFuture = _getAppVersion();
  }

  Future<String> _getAppVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return 'Version ${packageInfo.version} (Build ${packageInfo.buildNumber})';
    } catch (e) {
      return 'Failed to get version: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Version')),
      body: Center(
        child: FutureBuilder<String>(
          future: _versionFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else {
              return Text(
                snapshot.data ?? 'Unknown version',
                style: const TextStyle(fontSize: 20),
              );
            }
          },
        ),
      ),
    );
  }
}
