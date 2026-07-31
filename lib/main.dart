import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/app_theme.dart';
import 'theme/game_colors.dart';
import 'ui/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: GameColors.space,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const BottledStarApp());
}

class BottledStarApp extends StatelessWidget {
  const BottledStarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bottled Star',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const GameScreen(),
    );
  }
}
