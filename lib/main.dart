import 'package:flutter/material.dart';
import 'dart:async';
import 'services/location_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(LocationService.instance.initialize());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Login App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Login',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Email is required';
                  }
                  if (!value.contains('@')) {
                    return 'Enter valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
                  }
                  if (value.length < 6) {
                    return 'Minimum 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() {
                              _isLoading = true;
                            });

                            try {
                              await Future.delayed(const Duration(seconds: 2));

                              if (!context.mounted) return;

                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      HomePage(email: _emailController.text),
                                ),
                              );
                            } catch (error, stackTrace) {
                              debugPrint('Login flow failed: $error');
                              debugPrintStack(stackTrace: stackTrace);

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Login failed. Please try again.',
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            }
                          }
                        },
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final String email;

  const HomePage({super.key, required this.email});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final LocationService _locationService = LocationService.instance;
  StreamSubscription<LocationUpdate>? _locationSubscription;
  StreamSubscription<List<LocationUpdate>>? _historySubscription;
  double? _latitude;
  double? _longitude;
  bool _isStartingTracking = true;
  List<LocationUpdate> _history = <LocationUpdate>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _history = _locationService.getHistoryForDay(DateTime.now());
    _historySubscription = _locationService.historyStream.listen((history) {
      if (!mounted) return;
      setState(() {
        _history = _locationService.getHistoryForDay(DateTime.now());
      });
    });
    _startTrackingAndListen();
  }

  Future<void> _startTrackingAndListen() async {
    try {
      await _locationService.startTracking();
      if (!mounted) return;

      _locationSubscription = _locationService.locationStream.listen((
        location,
      ) {
        if (!mounted) return;
        setState(() {
          _latitude = location.latitude;
          _longitude = location.longitude;
        });
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to start tracking: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to start location tracking.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStartingTracking = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _historySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _formatTimestamp(DateTime value) {
    return value.toLocal().toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome 🎉', style: TextStyle(fontSize: 26)),
            const SizedBox(height: 10),
            Text(widget.email, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            if (_isStartingTracking)
              const CircularProgressIndicator()
            else ...[
              Text(
                _latitude == null ? 'Latitude: --' : 'Latitude: $_latitude',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _longitude == null ? 'Longitude: --' : 'Longitude: $_longitude',
                style: const TextStyle(fontSize: 16),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Presence History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _history.isEmpty
                  ? const Center(
                      child: Text('No accepted presence updates yet.'),
                    )
                  : ListView.separated(
                      itemCount: _history.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 8),
                      itemBuilder: (context, index) {
                        final item = _history[_history.length - 1 - index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Lat: ${item.latitude}, Lng: ${item.longitude}',
                          ),
                          subtitle: Text(
                            'Time: ${_formatTimestamp(item.timestamp)}\nH3: ${item.h3Cell ?? '--'}',
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _locationService.stopTracking();
                } catch (error, stackTrace) {
                  debugPrint('Logout stopTracking failed: $error');
                  debugPrintStack(stackTrace: stackTrace);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Stopped with warnings. Logging out anyway.',
                        ),
                      ),
                    );
                  }
                } finally {
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const MyHomePage(title: 'Login App'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
