import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Security',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFF4F4F9),
      ),
      home: const MainApp(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const HomePage(),
    const PreviousImagesPage(),
  ];

  void _onDrawerSelect(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context);
  }

  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _setupFCM();
  }

  void _setupFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission for iOS
    NotificationSettings settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      _logger.i("User granted permission for notifications");
    } else {
      _logger.w("User did not grant permission for notifications");
    }

    // Get the FCM token
    String? token = await messaging.getToken();
    _logger.i("FCM Token: $token");

    // Handle foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _logger.i('Received notification: ${message.notification!.title}');
        if (mounted) {
          // Only show dialog if widget is still mounted
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(message.notification!.title ?? 'No Title'),
              content: Text(message.notification!.body ?? 'No Body'),
              actions: [
                TextButton(
                  child: const Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        }
      }
    });

    // Handle background notifications
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
  }

  // Handle background messages
  Future<void> _backgroundMessageHandler(RemoteMessage message) async {
    _logger.i('Background message received: ${message.notification!.title}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Smart Security"),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Text('📷 Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Current Latest Image'),
              onTap: () => _onDrawerSelect(0),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Previous Images'),
              onTap: () => _onDrawerSelect(1),
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? latestImageUrl;
  String? latestTimestamp;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchLatestImage();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchLatestImage());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLatestImage() async {
    try {
      final response = await http.get(Uri.parse("https://test-rep-aji5.onrender.com/upload/latest"));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        setState(() {
          latestImageUrl = json['imageUrl'];
          latestTimestamp = json['timestamp'];
        });
      } else {
        throw Exception('Failed to load image');
      }
    } catch (e) {
      debugPrint('Error fetching latest image: $e');
    }
  }

  String _formatTimestamp(String timestamp) {
    DateTime dateTime = DateTime.parse(timestamp);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: latestImageUrl != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullScreenImagePage(
                          imageUrl: latestImageUrl!,
                          timestamp: latestTimestamp ?? '',
                        ),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: latestImageUrl!,
                        width: double.infinity,
                        height: 400,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const CircularProgressIndicator(),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '🕒 ${_formatTimestamp(latestTimestamp ?? '')}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            )
          : const CircularProgressIndicator(),
    );
  }
}

class PreviousImagesPage extends StatefulWidget {
  const PreviousImagesPage({super.key});

  @override
  State<PreviousImagesPage> createState() => _PreviousImagesPageState();
}

class _PreviousImagesPageState extends State<PreviousImagesPage> {
  List<dynamic> images = [];

  @override
  void initState() {
    super.initState();
    _fetchPreviousImages();
  }

  Future<void> _fetchPreviousImages() async {
    try {
      final response = await http.get(Uri.parse("https://test-rep-aji5.onrender.com/upload/all"));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          images = data.take(15).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching previous images: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return images.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: images.length,
            itemBuilder: (context, index) {
              final image = images[index];
              final String imageUrl = image['imageUrl'] as String;
              final String timestamp = image['timestamp']?.toString() ?? '';
              final formattedTimestamp = _formatTimestamp(timestamp);

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullScreenImagePage(
                        imageUrl: imageUrl,
                        timestamp: formattedTimestamp,
                      ),
                    ),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.all(12),
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: 200,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const CircularProgressIndicator(),
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '🕒 $formattedTimestamp',
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  String _formatTimestamp(String timestamp) {
    DateTime dateTime = DateTime.parse(timestamp);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }
}

class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;
  final String timestamp;

  const FullScreenImagePage({
    super.key,
    required this.imageUrl,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Captured @ $timestamp'),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const CircularProgressIndicator(),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        ),
      ),
    );
  }
}
