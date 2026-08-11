// ignore_for_file: use_build_context_synchronously

import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Manages the full App Open Ad lifecycle:
///   • Loading (with a 4-hour expiry guard required by Google policy)
///   • Showing (cold-start and foreground resume)
///   • Frequency capping (minimum interval between shows)
///   • Logging every event to Firestore (mirrors the banner/interstitial pattern)
class AppOpenAdManager {
  // ── Ad unit IDs ─────────────────────────────────────────────────────────
  // These are Google test IDs. Replace with your real IDs before release.
  static const String _adUnitId = 'ca-app-pub-3940256099942544/9257395921';

  // ── Frequency cap ────────────────────────────────────────────────────────
  /// Minimum time that must pass between two consecutive ad shows.
  /// Adjust this value to control how often the ad can appear.
  ///
  static const Duration minIntervalBetweenShows = Duration(minutes: 20);

  /// When the ad was last successfully shown to the user.
  DateTime? _lastShownTime;

  /// Returns true if not enough time has passed since the last show.
  bool get _isTooSoon {
    if (_lastShownTime == null) return false; // Never shown → always allow.
    return DateTime.now().difference(_lastShownTime!) < minIntervalBetweenShows;
  }

  // ── Ad expiry ────────────────────────────────────────────────────────────
  /// Google policy: a loaded ad must be shown within 4 hours or discarded.
  static const Duration _adExpiryDuration = Duration(hours: 4);

  /// When the current ad object was loaded from the network.
  DateTime? _adLoadTime;

  bool get _isAdExpired {
    if (_adLoadTime == null) return true;
    return DateTime.now().difference(_adLoadTime!) >= _adExpiryDuration;
  }

  // ── State ────────────────────────────────────────────────────────────────
  AppOpenAd? _appOpenAd;
  bool _isAdAvailable = false;

  /// Whether an ad is currently on screen (prevents double-showing).
  bool _isShowingAd = false;

  /// True only when an ad is in memory AND still within the 4-hour window.
  bool get isAdAvailable => _isAdAvailable && !_isAdExpired;

  // ── Load ─────────────────────────────────────────────────────────────────

  /// Loads a new App Open Ad. No-ops if a fresh ad is already in memory.
  void loadAd() {
    if (isAdAvailable) {
      log('AppOpenAd: already loaded and fresh – skipping load.');
      return;
    }

    log('AppOpenAd: loading (unit: $_adUnitId)');

    AppOpenAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          log('AppOpenAd: loaded successfully.');
          _appOpenAd = ad;
          _isAdAvailable = true;
          _adLoadTime = DateTime.now();
          _logEvent('loaded');
        },
        onAdFailedToLoad: (error) {
          log('AppOpenAd: failed to load – ${error.message}');
          _appOpenAd = null;
          _isAdAvailable = false;
          _adLoadTime = null;
          _logEvent(
            'load_failed',
            extra: {'errorCode': error.code, 'errorMessage': error.message},
          );
        },
      ),
    );
  }

  // ── Show ─────────────────────────────────────────────────────────────────

  /// Shows the ad if it is available, not expired, and outside the frequency
  /// cap window.
  ///
  /// [onComplete] is always called – whether the ad was shown, skipped, or
  /// failed – so callers (e.g. SplashScreen) are never left waiting.
  void showAdIfAvailable({VoidCallback? onComplete}) {
    // Guard: already on screen.
    if (_isShowingAd) {
      log('AppOpenAd: already showing – skipping.');
      onComplete?.call();
      return;
    }

    // Guard: frequency cap.
    if (_isTooSoon) {
      final remaining =
          minIntervalBetweenShows - DateTime.now().difference(_lastShownTime!);
      final mins = remaining.inMinutes;
      log('AppOpenAd: frequency cap – next show allowed in ~$mins min.');
      _logEvent(
        'skipped',
        extra: {'reason': 'frequency_cap', 'remaining_minutes': mins},
      );
      onComplete?.call();
      return;
    }

    // Guard: ad not ready or expired.
    if (!isAdAvailable) {
      log(
        'AppOpenAd: not available (${_isAdExpired ? "expired" : "not loaded"}) – skipping.',
      );
      _logEvent(
        'skipped',
        extra: {'reason': _isAdExpired ? 'expired' : 'not_loaded'},
      );
      loadAd(); // Pre-load for next opportunity.
      onComplete?.call();
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        log('AppOpenAd: showing full-screen content.');
        _isShowingAd = true;
        _lastShownTime = DateTime.now(); // ← stamp the show time for the cap
        _logEvent('showed');
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        log('AppOpenAd: failed to show – ${error.message}');
        _logEvent(
          'show_failed',
          extra: {'errorCode': error.code, 'errorMessage': error.message},
        );
        _isShowingAd = false;
        _isAdAvailable = false;
        ad.dispose();
        _appOpenAd = null;
        loadAd();
        onComplete?.call();
      },
      onAdDismissedFullScreenContent: (ad) {
        log('AppOpenAd: dismissed.');
        _logEvent('dismissed');
        _isShowingAd = false;
        _isAdAvailable = false;
        ad.dispose();
        _appOpenAd = null;
        loadAd(); // Pre-load for next foreground event.
        onComplete?.call();
      },
      onAdImpression: (ad) {
        log('AppOpenAd: impression recorded.');
        _logEvent('impression');
      },
      onAdClicked: (ad) {
        log('AppOpenAd: clicked.');
        _logEvent('clicked');
      },
    );

    _appOpenAd!.show();
  }

  // ── Cleanup ──────────────────────────────────────────────────────────────

  void dispose() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _isAdAvailable = false;
  }

  // ── Firestore logging ────────────────────────────────────────────────────

  Future<void> _logEvent(
    String event, {
    Map<String, dynamic> extra = const {},
  }) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      await FirebaseFirestore.instance.collection('ad_events').add({
        'userId': userId,
        'adType': 'app_open',
        'event': event,
        'timestamp': FieldValue.serverTimestamp(),
        ...extra,
      });
    } catch (e) {
      log('AppOpenAd: failed to log event "$event": $e');
    }
  }
}
