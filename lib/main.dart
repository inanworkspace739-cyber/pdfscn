import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'views/home/home_view.dart';
import 'views/splash/splash_screen.dart';
import 'viewmodels/home_viewmodel.dart';
import 'core/constants/constants.dart';
import 'services/ad_service.dart';

// Global ad service instance
final AdService adService = AdService();
late AppLifecycleReactor appLifecycleReactor;

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Orientation is handled by Info.plist per device:
  // - iPhone: portrait only (UISupportedInterfaceOrientations)
  // - iPad:   portrait only (UISupportedInterfaceOrientations~ipad)
  // Do NOT call SystemChrome.setPreferredOrientations here — it overrides
  // Info.plist at runtime and forces iPad into iPhone compatibility mode.

  // Initialize AdMob
  await adService.initialize();

  // Set up app lifecycle observer for App Open Ads
  appLifecycleReactor = AppLifecycleReactor(adService: adService);
  appLifecycleReactor.listenToAppStateChanges();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(),
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,

        // iOS-style theme
        theme: ThemeData(
          useMaterial3: true,

          // Color Scheme
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppConstants.primaryColor,
            brightness: Brightness.light,
          ),

          // Scaffold
          scaffoldBackgroundColor: AppConstants.backgroundColor,

          // AppBar
          appBarTheme: const AppBarTheme(
            backgroundColor: AppConstants.cardColor,
            foregroundColor: AppConstants.textPrimary,
            elevation: 0,
            centerTitle: false,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
          ),

          // Card
          cardTheme: CardThemeData(
            color: AppConstants.cardColor,
            elevation: AppConstants.cardElevation,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
          ),

          // Elevated Button
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingMedium,
                vertical: AppConstants.paddingSmall,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              textStyle: AppTextStyles.buttonText,
            ),
          ),

          // Text Button
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.primaryColor,
              textStyle: AppTextStyles.buttonText,
            ),
          ),

          // Icon Button
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              foregroundColor: AppConstants.primaryColor,
            ),
          ),

          // Floating Action Button
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: AppConstants.primaryColor,
            foregroundColor: Colors.white,
            elevation: 4,
          ),

          // Progress Indicator
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: AppConstants.primaryColor,
          ),

          // Snackbar
          snackBarTheme: SnackBarThemeData(
            backgroundColor: AppConstants.textPrimary,
            contentTextStyle: const TextStyle(color: Colors.white),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
          ),

          // Input Decoration
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppConstants.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              borderSide: const BorderSide(
                color: AppConstants.primaryColor,
                width: 2,
              ),
            ),
          ),

          // Divider
          dividerTheme: const DividerThemeData(
            color: AppConstants.textSecondary,
            thickness: 0.5,
          ),
        ),

        // Routes
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/home': (context) => const HomeView(),
        },

        // Home Screen
        home: const SplashScreen(),
      ),
    );
  }
}
