import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';
import '../../services/ad_service.dart';
import '../home/home_view.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AdService _adService = AdService();

  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // Show splash screen for 3 seconds to allow ad to load
    await Future.delayed(const Duration(seconds: 3));

    // Wait a bit more if ad isn't loaded yet
    if (!_adService.isAdAvailable) {
      await Future.delayed(const Duration(seconds: 2));
    }

    // Show App Open Ad before navigating to home
    if (_adService.isAdAvailable) {
      await _adService.showAppOpenAdIfAvailable();
      // Wait for ad to be shown and dismissed
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeView(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),

            // App Icon
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                borderRadius: BorderRadius.circular(24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'lib/Assets/icon.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // App Title
            const Text(
              'PDF Scanner',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppConstants.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const Text(
              'Edit & Convert',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.red,
                letterSpacing: -0.5,
              ),
            ),

            const Spacer(flex: 2),

            // Loading Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: const SizedBox(
                width: 200,
                height: 6,
                child: const LinearProgressIndicator(
                  backgroundColor: Color(0xFFF0F0F0),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
