import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'announcement_creation_screen.dart';

class AnnouncementManagementScreen extends StatefulWidget {
  const AnnouncementManagementScreen({super.key});

  @override
  State<AnnouncementManagementScreen> createState() => _AnnouncementManagementScreenState();
}

class _AnnouncementManagementScreenState extends State<AnnouncementManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _announcements = [];

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('announcements')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        _announcements = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load announcements: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteAnnouncement(int index) async {
    final ann = _announcements[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this announcement? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog
              setState(() {
                _isLoading = true;
              });
              try {
                await Supabase.instance.client
                    .from('announcements')
                    .delete()
                    .eq('id', ann['id']);
                
                await _fetchAnnouncements();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Announcement deleted successfully.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic isoDate) {
    if (isoDate == null) return 'N/A';
    try {
      DateTime dt = DateTime.parse(isoDate.toString()).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (e) {
      return isoDate.toString();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return const Color(0xFF4CAF50);
      case 'draft':
        return const Color(0xFFFFB300);
      case 'expired':
        return const Color(0xFFE53935);
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Announcement Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
              ? const Center(child: Text('No announcements found.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _announcements.length,
                  itemBuilder: (context, index) {
                    final ann = _announcements[index];
                    final String title = ann['title'] ?? 'No Title';
                    final String content = ann['content'] ?? '';
                    final String status = ann['status'] ?? 'draft';
                    final String targetRole = ann['target_role'] ?? 'All Users';
                    final String priority = ann['priority_level'] ?? 'Normal';
                    
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AnnouncementCreationScreen(existingAnnouncement: ann),
                            ),
                          );
                          if (result == true) {
                            _fetchAnnouncements();
                          }
                        },
                        child:Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF212121),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _getStatusColor(status)),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(status),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Content Preview
                              Text(
                                content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF757575), fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              
                              const Divider(height: 1, color: Color(0xFFEEEEEE)),
                              const SizedBox(height: 12),

                              // Meta Tags
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  // Priority Badge
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.flag, size: 14, color: _getPriorityColor(priority)),
                                      const SizedBox(width: 4),
                                      Text(
                                        priority,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _getPriorityColor(priority),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Role Badge
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.group, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        targetRole,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  // Date Info
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDate(ann['publish_at'] ?? ann['created_at']),
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // Actions
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AnnouncementCreationScreen(existingAnnouncement: ann),
                                        ),
                                      );
                                      if (result == true) {
                                        _fetchAnnouncements();
                                      }
                                    },
                                    tooltip: 'Edit Announcement',
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _deleteAnnouncement(index),
                                    tooltip: 'Delete Announcement',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AnnouncementCreationScreen()),
          );
          if (result == true) {
            _fetchAnnouncements();
          }
        },
        backgroundColor: const Color(0xFF1565C0),
        tooltip: 'Create Announcement',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
