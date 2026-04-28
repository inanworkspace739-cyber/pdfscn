import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob Ad Service for PDFSC
/// Handles App Open Ads and Interstitial Ads
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  AppOpenAd? _appOpenAd;
  InterstitialAd? _interstitialAd;
  bool _isShowingAd = false;
  bool _isAdLoaded = false;
  bool _isInterstitialLoaded = false;

  /// iOS Test Ad Unit ID (Replace with your real ad unit IDs for production)
  static String get appOpenAdUnitId {
    if (Platform.isIOS) {
      // iOS test ad unit ID
      return 'ca-app-pub-9283129936552011/4888663507';
    } else {
      throw UnsupportedError('This app is iOS only');
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isIOS) {
      // iOS test interstitial ad unit ID
      return 'ca-app-pub-9283129936552011/9343960015';
    } else {
      throw UnsupportedError('This app is iOS only');
    }
  }

  /// Initialize the Mobile Ads SDK
  Future<void> initialize() async {
    await MobileAds.instance.initialize();

    // Load the first App Open Ad
    loadAppOpenAd();

    // Load the first Interstitial Ad
    loadInterstitialAd();
  }

  /// Load App Open Ad
  Future<void> loadAppOpenAd({int retryAttempt = 0}) async {
    await AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('App Open Ad loaded successfully');
          _appOpenAd = ad;
          _isAdLoaded = true;
          _appOpenAd!.setImmersiveMode(true);
        },
        onAdFailedToLoad: (error) {
          debugPrint('App Open Ad failed to load: ${error.message}');
          _isAdLoaded = false;
          if (retryAttempt < 3) {
            Future.delayed(Duration(seconds: (retryAttempt + 1) * 2), () {
              loadAppOpenAd(retryAttempt: retryAttempt + 1);
            });
          }
        },
      ),
    );
  }

  /// Load Interstitial Ad
  Future<void> loadInterstitialAd({int retryAttempt = 0}) async {
    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('Interstitial Ad loaded successfully');
          _interstitialAd = ad;
          _isInterstitialLoaded = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial Ad failed to load: ${error.message}');
          _isInterstitialLoaded = false;
          if (retryAttempt < 3) {
            Future.delayed(Duration(seconds: (retryAttempt + 1) * 2), () {
              loadInterstitialAd(retryAttempt: retryAttempt + 1);
            });
          }
        },
      ),
    );
  }

  /// Show App Open Ad if available
  Future<void> showAppOpenAdIfAvailable() async {
    if (!_isAdLoaded) {
      debugPrint('App Open Ad not loaded yet');
      await loadAppOpenAd();
      return;
    }

    if (_isShowingAd) {
      debugPrint('App Open Ad already showing');
      return;
    }

    if (_appOpenAd == null) {
      debugPrint('App Open Ad is null');
      await loadAppOpenAd();
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('App Open Ad showed');
        _isShowingAd = true;
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('App Open Ad failed to show: ${error.message}');
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        _isAdLoaded = false;
        loadAppOpenAd();
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('App Open Ad dismissed');
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        _isAdLoaded = false;
        loadAppOpenAd();
      },
    );

    await _appOpenAd!.show();
  }

  /// Show Interstitial Ad and execute callback when dismissed
  Future<void> showInterstitialAd({VoidCallback? onAdDismissed}) async {
    if (!_isInterstitialLoaded || _interstitialAd == null) {
      debugPrint('Interstitial Ad not loaded yet');
      onAdDismissed?.call();
      loadInterstitialAd();
      return;
    }

    if (_isShowingAd) {
      debugPrint('An ad is already showing');
      onAdDismissed?.call();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('Interstitial Ad showed');
        _isShowingAd = true;
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Interstitial Ad failed to show: ${error.message}');
        _isShowingAd = false;
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialLoaded = false;
        loadInterstitialAd();
        onAdDismissed?.call();
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('Interstitial Ad dismissed');
        _isShowingAd = false;
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialLoaded = false;
        loadInterstitialAd();
        onAdDismissed?.call();
      },
    );

    await _interstitialAd!.show();
  }

  /// Check if app open ad is available
  bool get isAdAvailable => _isAdLoaded && _appOpenAd != null;

  /// Check if interstitial ad is available
  bool get isInterstitialAvailable =>
      _isInterstitialLoaded && _interstitialAd != null;

  /// Dispose resources
  void dispose() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}

/// App Lifecycle Observer for showing App Open Ads
class AppLifecycleReactor with WidgetsBindingObserver {
  final AdService adService;

  AppLifecycleReactor({required this.adService});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Show ad when app comes to foreground
      adService.showAppOpenAdIfAvailable();
    }
  }

  void listenToAppStateChanges() {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
