import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'announcement_creation_screen.dart';
import '../core/announcement_details_screen.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/shimmer_skeletons.dart';

class AnnouncementManagementScreen extends StatefulWidget {
  const AnnouncementManagementScreen({super.key});

  @override
  State<AnnouncementManagementScreen> createState() => _AnnouncementManagementScreenState();
}

class _AnnouncementManagementScreenState extends State<AnnouncementManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _announcements = [];
  final ScrollController _scrollController = ScrollController();
  bool _hasMore = true;
  bool _isFetchingMore = false;
  bool _isSelectionMode = false;
  bool _allSelected = false;
  final int _pageSize = 10;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isFetchingMore && _hasMore) {
          _fetchAnnouncements(loadMore: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchAnnouncements({bool loadMore = false}) async {
    if (loadMore) {
      if (mounted) {
        setState(() {
          _isFetchingMore = true;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _offset = 0;
          _hasMore = true;
          _announcements.clear();
        });
      }
    }

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('announcements')
          .select()
          .order('created_at', ascending: false)
          .range(_offset, _offset + _pageSize - 1);

      final List<Map<String, dynamic>> fetched = List<Map<String, dynamic>>.from(response).map((a) => {...a, 'isChecked': false}).toList();

      // Define priority order: High (0), Medium (1), Low (2)
      final Map<String, int> priorityMap = {'High': 0, 'Medium': 1, 'Low': 2};

      fetched.sort((a, b) {
        int pA = priorityMap[a['priority_level']] ?? 3;
        int pB = priorityMap[b['priority_level']] ?? 3;
        if (pA != pB) {
          return pA.compareTo(pB);
        }
        DateTime dateA = DateTime.tryParse(a['created_at'].toString()) ?? DateTime(0);
        DateTime dateB = DateTime.tryParse(b['created_at'].toString()) ?? DateTime(0);
        return dateB.compareTo(dateA);
      });

      setState(() {
        if (loadMore) {
          _announcements.addAll(fetched);
        } else {
          _announcements = fetched;
        }
        _isLoading = false;
        _isFetchingMore = false;
        _hasMore = fetched.length == _pageSize;
        _offset += fetched.length;
      });
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
        snackbar('Failed to load announcements: $e', Colors.red);
      }
    }
  }

  Future<void> _deleteAnnouncement(Map<String, dynamic> ann) async {
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
                final supabase = Supabase.instance.client;

                // --- Storage Image Deletion ---
                final String? imageUrl = ann['image_url'];
                if (imageUrl != null && imageUrl.isNotEmpty) {
                  try {
                    // Extract the filename from the public URL
                    // The URL format is normally: .../announcements/images/filename
                    final Uri uri = Uri.parse(imageUrl);
                    final String bucketName = 'announcements';
                    final int bucketIndex = uri.pathSegments.indexOf(bucketName);

                    if (bucketIndex != -1 && bucketIndex < uri.pathSegments.length - 1) {
                      // Get everything after the bucket name for the full path
                      final String storagePath = uri.pathSegments.sublist(bucketIndex + 1).join('/');
                      await supabase.storage.from(bucketName).remove([storagePath]);
                    }
                  } catch (storageError) {
                    debugPrint('Silent error: Failed to delete image from storage: $storageError');
                    // We continue deleting the db record even if storage deletion fails
                  }
                }
                // ------------------------------

                await supabase
                    .from('announcements')
                    .delete()
                    .eq('id', ann['id']);

                await _fetchAnnouncements();
                if (mounted) {
                  snackbar('Announcement and data deleted successfully.', Colors.green);
                }
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                  snackbar('Failed to delete: $e', Colors.red);
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
    return Theme(
      data: ThemeData.light(),
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(_isSelectionMode ? '${_announcements.where((a) => a['isChecked'] == true).length} Selected' : 'Announcement Management', style: const TextStyle(fontWeight: FontWeight.bold)),
          foregroundColor: Colors.black87,
          elevation: 2,
          shadowColor: Colors.lightBlue.withValues(alpha: 0.2),
          centerTitle: true,
          actions: [
            if (_isSelectionMode) ...[
              IconButton(
                icon: Icon(_allSelected ? Icons.check_box : Icons.check_box_outline_blank),
                onPressed: _toggleSelectAll,
                tooltip: 'Select All',
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                onPressed: _deleteSelectedAnnouncements,
                tooltip: 'Bulk Delete',
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    for (var a in _announcements) {
                      a['isChecked'] = false;
                    }
                  });
                },
              ),
            ]
          ],
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.lightBlue, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.lightBlue,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.lightBlue,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Published'),
              Tab(text: 'Drafts'),
              Tab(text: 'Expired'),
            ],
          ),
        ),
        body: SafeArea(
          child: _isLoading
              ? _buildAnnouncementSkeleton()
              : TabBarView(
                  children: [
                    _buildList(_announcements),
                    _buildList(_announcements.where((a) => a['status']?.toString().toLowerCase() == 'published').toList()),
                    _buildList(_announcements.where((a) => a['status']?.toString().toLowerCase() == 'draft').toList()),
                    _buildList(_announcements.where((a) => a['status']?.toString().toLowerCase() == 'expired').toList()),
                  ],
                ),
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: const Color(0xFF1565C0).withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnnouncementCreationScreen()),
              );
              if (result == true) {
                _fetchAnnouncements();
              }
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            tooltip: 'Create Announcement',
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ),
      ),
    );
  }

  void _toggleSelectAll() {
    setState(() {
      _allSelected = !_allSelected;
      for (var a in _announcements) {
        a['isChecked'] = _allSelected;
      }
    });
  }

  void _deleteSelectedAnnouncements() {
    final selectedAnnouncements = _announcements.where((a) => a['isChecked'] == true).toList();
    if (selectedAnnouncements.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Delete'),
        content: Text('Are you sure you want to delete ${selectedAnnouncements.length} announcements? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                final supabase = Supabase.instance.client;
                for (var ann in selectedAnnouncements) {
                  // Optional: Delete storage images if any (simplified for batch)
                  await supabase.from('announcements').delete().eq('id', ann['id']);
                }
                
                snackbar('Announcements deleted successfully', Colors.green);
                _fetchAnnouncements();
                setState(() => _isSelectionMode = false);
              } catch (e) {
                snackbar('Error deleting announcements: $e', Colors.red);
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: BaseSkeleton(width: double.infinity, height: 180, borderRadius: 12),
        );
      },
    );
  }

  Widget _buildList(List<Map<String, dynamic>> displayedAnnouncements) {
    if (displayedAnnouncements.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchAnnouncements,
        color: Colors.lightBlue,
        child: ListView(
          children: const [
            SizedBox(height: 100),
            Center(child: Text('No announcements found.', style: TextStyle(color: Colors.grey))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchAnnouncements,
      color: Colors.lightBlue,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: displayedAnnouncements.length + (_isFetchingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == displayedAnnouncements.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final ann = displayedAnnouncements[index];
          final bool isChecked = ann['isChecked'] ?? false;
          final String title = ann['title'] ?? 'No Title';
          final String content = ann['content'] ?? '';
          final String status = ann['status'] ?? 'draft';
          final String targetRole = ann['target_role'] ?? 'All Users';
          final String priority = ann['priority_level'] ?? 'Normal';

          return GestureDetector(
            onLongPress: () {
              setState(() {
                _isSelectionMode = true;
                ann['isChecked'] = true;
              });
            },
            onTap: _isSelectionMode ? () {
              setState(() {
                ann['isChecked'] = !isChecked;
              });
            } : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: _isSelectionMode && isChecked ? Border.all(color: Colors.lightBlue, width: 2) : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  if (_isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 8),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isChecked,
                            onChanged: (val) => setState(() => ann['isChecked'] = val),
                            activeColor: Colors.lightBlue,
                          ),
                          const Text('Select Announcement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isSelectionMode ? () => setState(() => ann['isChecked'] = !isChecked) : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AnnouncementDetailsScreen(announcement: ann),
                          ),
                        );
                      },
                      child: Padding(
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
                                    color: _getStatusColor(status).withValues(alpha: 0.1),
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
                            if (!_isSelectionMode)
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
                                    onPressed: () => _deleteAnnouncement(ann),
                                    tooltip: 'Delete Announcement',
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}