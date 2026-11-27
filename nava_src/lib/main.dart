import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'screens.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.pooyan.nava.audio',
    androidNotificationChannelName: 'نوا',
    androidNotificationOngoing: true,
  );
  await store.init();
  runApp(const NavaRoot());
}
