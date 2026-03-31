import 'package:flutter/material.dart';

class AnnouncementDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> announcement;

  const AnnouncementDetailsScreen({super.key, required this.announcement});

  @override
  Widget build(BuildContext context) {
    final String title = announcement['title'] ?? 'No Title';
    final String content = announcement['content'] ?? '';
    final String? imageUrl = announcement['image_url'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement Details'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Show image first
            if (imageUrl != null && imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 250,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              )
            else
              Container(
                height: 200,
                color: Colors.grey[100],
                child: const Icon(Icons.campaign, size: 80, color: Colors.lightBlue),
              ),

            const SizedBox(height: 24),

            // 2. Show the title in bold text and center it below the image
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. The content description last
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Text(
                content,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Color(0xFF424242),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
