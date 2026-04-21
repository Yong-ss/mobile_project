import 'package:flutter/material.dart';
import '../../widgets/shimmer_skeletons.dart';

class AnnouncementDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> announcement;

  const AnnouncementDetailsScreen({super.key, required this.announcement});

  @override
  State<AnnouncementDetailsScreen> createState() => _AnnouncementDetailsScreenState();
}

class _AnnouncementDetailsScreenState extends State<AnnouncementDetailsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Simulate loading for the shimmer effect
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Announcement Details', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
        ),
        body: const AnnouncementDetailsSkeletonUI(),
      );
    }

    final String title = widget.announcement['title'] ?? 'No Title';
    final String content = widget.announcement['content'] ?? '';
    final String? imageUrl = widget.announcement['image_url'];

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement Details', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: imageUrl != null && imageUrl.isNotEmpty,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Fancy Image Header
            Stack(
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(imageUrl.split(',')[0]),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                            Theme.of(context).scaffoldBackgroundColor,
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.lightBlue.shade300, Colors.blue.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(Icons.campaign, size: 100, color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // 2. Title and Content Container
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 60,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.lightBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.7,
                      color: isDark ? Colors.white70 : Colors.black54,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}