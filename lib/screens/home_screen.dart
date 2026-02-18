import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/location_update.dart';
import '../services/location_service.dart';
import '../services/session_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/interval_selector.dart';
import '../widgets/location_card.dart';
import '../widgets/status_card.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.email});

  final String email;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<int> _intervalOptions = <int>[2, 5, 8, 10, 15, 20];

  final LocationService _locationService = LocationService.instance;

  final ValueNotifier<bool> _isTrackingActive = ValueNotifier<bool>(false);
  final ValueNotifier<int> _selectedInterval = ValueNotifier<int>(20);
  final ValueNotifier<LocationUpdate?> _latestUpdate =
      ValueNotifier<LocationUpdate?>(null);
  final ValueNotifier<List<LocationUpdate>> _history =
      ValueNotifier<List<LocationUpdate>>(<LocationUpdate>[]);

  StreamSubscription<LocationUpdate>? _locationSubscription;
  StreamSubscription<List<LocationUpdate>>? _historySubscription;

  @override
  void initState() {
    super.initState();
    _selectedInterval.value = _locationService.heartbeatIntervalMinutes;
    _history.value = _locationService.historySnapshot;

    _historySubscription = _locationService.historyStream.listen((history) {
      _history.value = history;
    });

    _locationSubscription = _locationService.locationStream.listen((update) {
      _latestUpdate.value = update;
    });

    _startTracking();
  }

  Future<void> _onIntervalChanged(int value) async {
    _selectedInterval.value = value;
    await _locationService.setHeartbeatIntervalMinutes(value);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Heartbeat interval set to $value minutes.')),
      );
    }
  }

  Future<void> _startTracking() async {
    try {
      await _locationService.startTracking();
      _isTrackingActive.value = true;
    } catch (error, stackTrace) {
      debugPrint('Failed to start tracking: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to start location tracking.')),
        );
      }
    }
  }

  Future<void> _refreshHistory() async {
    _history.value = _locationService.historySnapshot;
  }

  Future<void> _clearHistory() async {
    await _locationService.clearHistory();
    _history.value = _locationService.historySnapshot;
  }

  Future<void> _openMaps(LocationUpdate update) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${update.latitude},${update.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _stopTracking() async {
    try {
      await _locationService.stopTracking();
      _isTrackingActive.value = false;

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tracking stopped.')));
      }
    } catch (error, stackTrace) {
      debugPrint('Stop tracking failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to stop tracking.')),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      await _locationService.stopTracking();
    } catch (error, stackTrace) {
      debugPrint('Logout stopTracking failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      await SessionService.clearLogin();
      _isTrackingActive.value = false;
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _historySubscription?.cancel();

    _isTrackingActive.dispose();
    _selectedInterval.dispose();
    _latestUpdate.dispose();
    _history.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Krozd Tracker - Battery POC'),
        actions: [
          IconButton(
            onPressed: _refreshHistory,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: _clearHistory,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ListView(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: _isTrackingActive,
              builder: (context, isTrackingActive, child) {
                return ValueListenableBuilder<List<LocationUpdate>>(
                  valueListenable: _history,
                  builder: (context, history, child) {
                    return ValueListenableBuilder<LocationUpdate?>(
                      valueListenable: _latestUpdate,
                      builder: (context, latest, child) {
                        return ValueListenableBuilder<int>(
                          valueListenable: _selectedInterval,
                          builder: (context, selectedInterval, child) {
                            final activity = latest?.activity ?? 'still';
                            return StatusCard(
                              trackingActive: isTrackingActive,
                              updateIntervalMinutes: selectedInterval,
                              activityLabel: activity,
                              recordedCount: history.length,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            ValueListenableBuilder<int>(
              valueListenable: _selectedInterval,
              builder: (context, selectedInterval, child) {
                return IntervalSelector(
                  values: _intervalOptions,
                  selectedValue: selectedInterval,
                  enabled: true,
                  onChanged: (value) {
                    unawaited(_onIntervalChanged(value));
                  },
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            ValueListenableBuilder<List<LocationUpdate>>(
              valueListenable: _history,
              builder: (context, history, child) {
                if (history.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Center(
                      child: Text('No accepted presence updates yet.'),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[history.length - 1 - index];
                    return LocationCard(
                      index: history.length - index,
                      update: item,
                      onCoordinatesTap: () => _openMaps(item),
                      onOpenMaps: () => _openMaps(item),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: _stopTracking,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
                child: const Text('Stop Tracking'),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Logged in as ${widget.email}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
