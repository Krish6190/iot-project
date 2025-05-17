import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_core/firebase_core.dart';

class InfoScreen extends StatelessWidget {
  final VoidCallback onDismiss;
  const InfoScreen({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: const Color(0xFF181A20),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, color: Colors.indigoAccent, size: 72),
                const SizedBox(height: 24),
                const Text(
                  'IoT Security System',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Developed by:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Krish (2023UEC2608)\n'
                  'Nishant (2023UEC2606)\n'
                  'Ayaan (2023UEC2588)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 30),
                const Icon(Icons.touch_app, color: Colors.indigoAccent, size: 32),
                const SizedBox(height: 10),
                const Text(
                  'Tap anywhere to continue',
                  style: TextStyle(
                    color: Colors.indigoAccent,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();
  
  await NotificationService.initialize();

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    'image-polling',
    'imagePollingTask',
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
  );
  
  runApp(const RootApp());
}

class RootApp extends StatefulWidget {
  const RootApp({super.key});

  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  bool _showSplash = true;

  void _dismissSplash() {
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Security',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF181A20),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF23253A),
          elevation: 2,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        tabBarTheme: const TabBarTheme(
          labelColor: Colors.indigoAccent,
          unselectedLabelColor: Colors.white70,
          labelStyle: TextStyle(fontWeight: FontWeight.bold),
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(color: Colors.indigoAccent, width: 2),
          ),
        ),
      ),
      home: _showSplash ? InfoScreen(onDismiss: _dismissSplash) : const MyApp(),
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final prefs = await SharedPreferences.getInstance();
    final lastTimestamp = prefs.getString('lastTimestamp');
    try {
      final response = await http.get(Uri.parse('https://idk-9nf0.onrender.com/upload/latest'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newTimestamp = DateTime.parse(data['timestamp']).toIso8601String();
        if (lastTimestamp == null || newTimestamp.compareTo(lastTimestamp) > 0) {
          await NotificationService.showNotification(
            'New Image Uploaded!',
            'Tap to view the latest photo'
          );
          await prefs.setString('lastTimestamp', newTimestamp);
        }
      }
    } catch (e) {
      print('Background task error: $e');
    }
    return Future.value(true);
  });
}

class ImageData {
  final String imageUrl;
  final DateTime timestamp;

  ImageData({required this.imageUrl, required this.timestamp});

  factory ImageData.fromJson(Map<String, dynamic> json) {
    return ImageData(
      imageUrl: json['imageUrl'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ImageData? latestImage;
  List<ImageData> olderImages = [];
  Timer? _pollingTimer;
  final String baseUrl = 'https://idk-9nf0.onrender.com/upload';
  late SharedPreferences _prefs;
  int _currentTabIndex = 0;

  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _initializePrefs();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    _initializeData();
    _startPolling();
  }

  Future<void> _initializePrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  void _initializeData() async {
    await fetchLatestImage();
    await fetchOlderImages();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkForNewImage();
    });
  }

  Future<void> fetchLatestImage() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/latest'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          latestImage = ImageData.fromJson(data);
        });
        await _prefs.setString('lastTimestamp', latestImage!.timestamp.toIso8601String());
      }
    } catch (e) {
      print('Error fetching latest image: $e');
    }
  }

  Future<void> fetchOlderImages() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/all?limit=15'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<ImageData> images = data.map((json) => ImageData.fromJson(json)).toList();
        setState(() {
          olderImages = images;
        });
      }
    } catch (e) {
      print('Error fetching older images: $e');
    }
  }

  Future<void> checkForNewImage() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/latest'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newImage = ImageData.fromJson(data);
        final lastTimestamp = _prefs.getString('lastTimestamp');
        if (lastTimestamp == null ||
            newImage.timestamp.toIso8601String().compareTo(lastTimestamp) > 0) {
          await NotificationService.showNotification(
            'New Image Available',
            'Open app to view the latest upload'
          );
          setState(() {
            latestImage = newImage;
          });
          await _prefs.setString('lastTimestamp', newImage.timestamp.toIso8601String());
          await fetchOlderImages();
        }
      }
    } catch (e) {
      print('Error checking for new image: $e');
    }
  }

  void _openFullscreen(BuildContext context, int initialIndex) {
    final allImages = [if (latestImage != null) latestImage!, ...olderImages];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenGallery(
          images: allImages,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _onRefreshPressed() async {
    setState(() => _isRefreshing = true);
    await fetchLatestImage();
    await fetchOlderImages();
    setState(() => _isRefreshing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Images refreshed!'),
        backgroundColor: Colors.indigo,
      ),
    );
  }

  Widget shimmerLoadingPlaceholder({double? width, double? height, BorderRadius? borderRadius}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[500]!,
      child: Container(
        width: width ?? double.infinity,
        height: height ?? 200,
        decoration: BoxDecoration(
          color: Colors.grey[700],
          borderRadius: borderRadius ?? BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget shimmerTextPlaceholder({double width = 120, double height = 18}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[500]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[700],
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Viewer'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Latest'),
            Tab(text: 'Older Images'),
          ],
        ),
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton(
              onPressed: _isRefreshing ? null : _onRefreshPressed,
              backgroundColor: Colors.indigo,
              child: _isRefreshing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    )
                  : const Icon(Icons.refresh),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _isRefreshing || latestImage == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      shimmerLoadingPlaceholder(
                        width: MediaQuery.of(context).size.width * 0.9,
                        height: MediaQuery.of(context).size.height * 0.6,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      const SizedBox(height: 20),
                      shimmerTextPlaceholder(width: 120, height: 18),
                      const SizedBox(height: 8),
                      shimmerTextPlaceholder(width: 180, height: 20),
                    ],
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => _openFullscreen(context, 0),
                        child: Hero(
                          tag: latestImage!.imageUrl,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: CachedNetworkImage(
                              imageUrl: latestImage!.imageUrl,
                              width: MediaQuery.of(context).size.width * 0.9,
                              height: MediaQuery.of(context).size.height * 0.6,
                              fit: BoxFit.cover,
                              fadeInDuration: Duration.zero,
                              placeholder: (_, __) => shimmerLoadingPlaceholder(
                                width: MediaQuery.of(context).size.width * 0.9,
                                height: MediaQuery.of(context).size.height * 0.6,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              errorWidget: (_, __, ___) => const Icon(Icons.error, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Uploaded at :',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            latestImage!.timestamp.toLocal().toString().split('.')[0],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          olderImages.isEmpty
              ? const Center(child: Text('No images found', style: TextStyle(color: Colors.white)))
              : RefreshIndicator(
                  onRefresh: fetchOlderImages,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: olderImages.length,
                    itemBuilder: (context, index) {
                      final img = olderImages[index];
                      return GestureDetector(
                        onTap: () => _openFullscreen(context, index),
                        child: Hero(
                          tag: img.imageUrl,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: img.imageUrl,
                              fit: BoxFit.cover,
                              fadeInDuration: Duration.zero,
                              placeholder: (_, __) => shimmerLoadingPlaceholder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}

class FullscreenGallery extends StatefulWidget {
  final List<ImageData> images;
  final int initialIndex;

  const FullscreenGallery({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<FullscreenGallery> {
  late PageController _pageController;
  int _currentPage = 0;
  List<PhotoViewController> _photoControllers = [];

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _photoControllers = List.generate(
      widget.images.length,
      (_) => PhotoViewController(),
    );
    _photoControllers[_currentPage].outputStateStream.listen(_handlePhotoViewState);
    _pageController.addListener(() {
      final newPage = _pageController.page?.round() ?? 0;
      if (newPage != _currentPage) {
        _photoControllers[_currentPage].outputStateStream.drain();
        _currentPage = newPage;
        _photoControllers[_currentPage].outputStateStream.listen(_handlePhotoViewState);
        setState(() {});
      }
    });
  }

  bool get _isZoomed {
    final scale = _photoControllers[_currentPage].scale ?? 1.0;
    return scale > 1.0;
  }

  void _handlePhotoViewState(PhotoViewControllerValue value) {
    setState(() {});
  }

  @override
  void dispose() {
    for (var controller in _photoControllers) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              physics: _isZoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                final image = widget.images[index];
                return PhotoView(
                  controller: _photoControllers[index],
                  imageProvider: NetworkImage(image.imageUrl),
                  loadingBuilder: (_, __) => Center(
                    child: Shimmer.fromColors(
                      baseColor: Colors.grey[800]!,
                      highlightColor: Colors.grey[500]!,
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.error, color: Colors.white)),
                  backgroundDecoration: const BoxDecoration(color: Color(0xFF181A20)),
                  heroAttributes: PhotoViewHeroAttributes(tag: image.imageUrl),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                );
              },
              onPageChanged: (index) => setState(() => _currentPage = index),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentPage + 1}/${widget.images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
