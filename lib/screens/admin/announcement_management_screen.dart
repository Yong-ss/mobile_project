import 'package:flutter/material.dart';

class AnnouncementManagementScreen extends StatefulWidget {
  const AnnouncementManagementScreen({super.key});

  @override
  State<AnnouncementManagementScreen> createState() => _AnnouncementManagementScreenState();
}

class _AnnouncementManagementScreenState extends State<AnnouncementManagementScreen> {
  // Mock data for announcements
  final List<Map<String, String>> _announcements = [
    {
      'id': '1',
      'title': 'Welcome to Priscon!',
      'content': 'We are excited to launch our new marketplace for small sellers.',
      'date': '2026-03-01'
    },
    {
      'id': '2',
      'title': 'System Maintenance',
      'content': 'Priscon will be undergoing scheduled maintenance on Sunday at 2 AM.',
      'date': '2026-03-10'
    },
  ];

  void _showAnnouncementDialog({int? index}) {
    final bool isEditing = index != null;
    final TextEditingController titleController = TextEditingController(
      text: isEditing ? _announcements[index]['title'] : '',
    );
    final TextEditingController contentController = TextEditingController(
      text: isEditing ? _announcements[index]['content'] : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Announcement' : 'Create Announcement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(labelText: 'Content'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isEmpty || contentController.text.isEmpty) {
                return; // basic validation
              }

              setState(() {
                if (isEditing) {
                  _announcements[index]['title'] = titleController.text;
                  _announcements[index]['content'] = contentController.text;
                } else {
                  _announcements.add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'title': titleController.text,
                    'content': contentController.text,
                    'date': DateTime.now().toString().split(' ')[0], // YYYY-MM-DD
                  });
                }
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isEditing ? 'Announcement updated' : 'Announcement created')),
              );
            },
            child: Text(isEditing ? 'Update' : 'Create'),
          ),
        ],
      ),
    );
  }

  void _deleteAnnouncement(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this announcement?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _announcements.removeAt(index);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Announcement deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement Management'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
      ),
      body: _announcements.isEmpty
          ? const Center(child: Text('No announcements yet.'))
          : ListView.builder(
              itemCount: _announcements.length,
              itemBuilder: (context, index) {
                final announcement = _announcements[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(announcement['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(announcement['content'] ?? ''),
                        const SizedBox(height: 8),
                        Text('Date: ${announcement['date']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.lightBlue),
                          onPressed: () => _showAnnouncementDialog(index: index),
                          tooltip: 'Edit Announcement',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteAnnouncement(index),
                          tooltip: 'Delete Announcement',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAnnouncementDialog(),
        backgroundColor: Colors.lightBlue,
        tooltip: 'Create Announcement',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
