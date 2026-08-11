import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'game/modes/game_mode.dart';
import 'game/systems/achievement_store.dart';
import 'game/systems/purchases_controller.dart';
import 'theme/app_theme.dart';
import 'theme/game_colors.dart';
import 'ui/game_screen.dart';
import 'ui/menu/achievements_screen.dart';
import 'ui/menu/challenge_iap_preview_screen.dart';
import 'ui/menu/credits_screen.dart';
import 'ui/menu/menu_screen.dart';
import 'ui/menu/mode_select_screen.dart';
import 'ui/menu/options_screen.dart';
import 'ui/menu/scores_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebase();
  await AchievementStore.instance.load();
  await PurchasesController.instance.init();
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

Future<void> _initFirebase() async {
  // FlutterFire has no Linux plugin (Auth/Firestore). Gameplay still works;
  // test boards with: flutter run -d chrome
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
    debugPrint(
      'Firebase skipped on Linux (unsupported). Use Chrome/Android/iOS for boards.',
    );
    return;
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase unavailable: $e');
  }
}

class BottledStarApp extends StatelessWidget {
  const BottledStarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bottled Star',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      initialRoute: '/',
      routes: {
        '/': (_) => const MenuScreen(),
        '/mode': (_) => const ModeSelectScreen(),
        '/play': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final mode = args is GameMode ? args : GameMode.classic;
          return GameScreen(mode: mode);
        },
        '/scores': (_) => const ScoresScreen(),
        '/achievements': (_) => const AchievementsScreen(),
        '/options': (_) => const OptionsScreen(),
        '/credits': (_) => const CreditsScreen(),
        '/iap-preview': (_) => const ChallengeIapPreviewScreen(),
      },
    );
  }
}
