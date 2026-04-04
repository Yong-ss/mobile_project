import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/snackbar_helper.dart';

class AnnouncementCreationScreen extends StatefulWidget {
  final Map<String, dynamic>? existingAnnouncement;

  const AnnouncementCreationScreen({super.key, this.existingAnnouncement});

  @override
  State<AnnouncementCreationScreen> createState() => _AnnouncementCreationScreenState();
}

class _AnnouncementCreationScreenState extends State<AnnouncementCreationScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  String _priority = 'Medium';
  DateTime? _scheduleDate;
  DateTime? _expiryDate;
  String _targetRole = 'All Users';
  File? _imageFile;
  String? _existingImageUrl;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.existingAnnouncement != null) {
      final ann = widget.existingAnnouncement!;
      _titleController.text = ann['title'] ?? '';
      _messageController.text = ann['content'] ?? '';
      _priority = ann['priority_level'] ?? 'Medium';
      _targetRole = ann['target_role'] ?? 'All Users';
      _existingImageUrl = ann['image_url'];
      if (ann['publish_at'] != null) {
        _scheduleDate = DateTime.tryParse(ann['publish_at'].toString());
      }
      if (ann['expire_at'] != null) {
        _expiryDate = DateTime.tryParse(ann['expire_at'].toString());
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      snackbar('Error picking image: $e', Colors.red);
    }
  }

  Future<void> _selectDateTime(BuildContext context, bool isSchedule) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null && context.mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          final result = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isSchedule) {
            _scheduleDate = result;
          } else {
            _expiryDate = result;
          }
        });
      }
    }
  }

  Future<void> _saveAnnouncement({required String status}) async {
    if (_titleController.text.trim().isEmpty) {
      snackbar('Please enter an announcement title.', Colors.red);
      return;
    }
    if (_messageController.text.trim().isEmpty) {
      snackbar('Please enter an announcement message.', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      String? imageUrl = _existingImageUrl;

      // --- Image Upload to Supabase Storage ---
      if (_imageFile != null) {
        // If we are replacing an existing image, delete the old one first
        if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
          try {
            final Uri uri = Uri.parse(_existingImageUrl!);
            final String bucketName = 'announcements';
            final int bucketIndex = uri.pathSegments.indexOf(bucketName);
            if (bucketIndex != -1 && bucketIndex < uri.pathSegments.length - 1) {
              final String oldPath = uri.pathSegments.sublist(bucketIndex + 1).join('/');
              await supabase.storage.from(bucketName).remove([oldPath]);
            }
          } catch (e) {
            debugPrint('Failed to delete old image: $e');
          }
        }

        final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${_imageFile!.path.split(RegExp(r'[\\/]')).last}';
        final String path = 'images/$fileName';

        // Upload to the 'images' folder within the 'announcements' bucket
        await supabase.storage.from('announcements').upload(path, _imageFile!);

        // Get the Public URL
        imageUrl = supabase.storage.from('announcements').getPublicUrl(path);
      }
      // ----------------------------------------

      final data = {
        'title': _titleController.text.trim(),
        'content': _messageController.text.trim(),
        'priority_level': _priority,
        'target_role': _targetRole,
        'status': status,
        'image_url': imageUrl,
        'publish_at': _scheduleDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'expire_at': _expiryDate?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.existingAnnouncement != null) {
        // Update
        await supabase
            .from('announcements')
            .update(data)
            .eq('id', widget.existingAnnouncement!['id']);
      } else {
        // Insert
        await supabase.from('announcements').insert(data);
      }

      if (mounted) {
        Navigator.pop(context, true); // true indicates a refresh is needed
        snackbar('Announcement saved as $status successfully!', Colors.green);
      }
    } catch (e) {
      debugPrint('Error saving announcement: $e');
      if (mounted) {
        snackbar('Failed to save announcement: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }

  Widget _buildSegmentedButton({
    required String title,
    required List<String> options,
    required String currentValue,
    required void Function(String) onChanged,
    Map<String, Color>? dotColors,
  }) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF424242),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = option == currentValue;
              final dotColor = dotColors?[option] ?? Colors.grey;

              return GestureDetector(
                onTap: () => onChanged(option),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEDF2FF) : Colors.white,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF5C6BC0) : const Color(0xFFE0E0E0),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dotColors != null) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        option,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF283593) : const Color(0xFF616161),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(widget.existingAnnouncement != null ? 'Edit Announcement' : 'Create Announcement'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Announcement Title', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF424242))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'Enter announcement title...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),

            // Message
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Message', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF424242))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    maxLines: 6,
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Write your announcement message here...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_messageController.text.length} characters',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            // Priority Level
            _buildSegmentedButton(
              title: 'Priority Level',
              options: ['Low', 'Medium', 'High'],
              currentValue: _priority,
              onChanged: (val) => setState(() => _priority = val),
              dotColors: {
                'Low': Colors.blue,
                'Medium': Colors.orange,
                'High': Colors.red,
              },
            ),

            // Schedule
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Color(0xFF424242)),
                      SizedBox(width: 8),
                      Text('Schedule (Optional)', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF424242))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _selectDateTime(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _scheduleDate != null
                            ? DateFormat('dd/MM/yyyy HH:mm').format(_scheduleDate!)
                            : 'dd/mm/yyyy --:--',
                        style: TextStyle(
                          color: _scheduleDate != null ? Colors.black : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Leave empty to publish immediately',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Expiry
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Color(0xFF424242)),
                      SizedBox(width: 8),
                      Text('Expiry (Optional)', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF424242))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _selectDateTime(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _expiryDate != null
                                ? DateFormat('dd/MM/yyyy HH:mm').format(_expiryDate!)
                                : 'dd/mm/yyyy --:--',
                            style: TextStyle(
                              color: _expiryDate != null ? Colors.black : Colors.grey[600],
                            ),
                          ),
                          if (_expiryDate != null)
                            InkWell(
                              onTap: () => setState(() => _expiryDate = null),
                              child: const Icon(Icons.clear, size: 16, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Leave empty for no expiry',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Target Roles
            _buildSegmentedButton(
              title: 'Target Roles',
              options: ['All Users', 'Customers', 'Sellers'],
              currentValue: _targetRole,
              onChanged: (val) => setState(() => _targetRole = val),
              dotColors: {
                'All Users': Colors.purple,
                'Customers': Colors.blue,
                'Sellers': Colors.green,
              },
            ),

            // Add Image
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Image (Optional)', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF424242))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      InkWell(
                        onTap: _pickImage,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.upload_file, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _imageFile != null
                                ? _imageFile!.path.split('/').last.split('\\').last
                                : (_existingImageUrl != null ? 'Existing image loaded' : 'Choose File No file chosen'),
                            style: TextStyle(
                              color: _imageFile != null || _existingImageUrl != null ? Colors.black : Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Publish Warning Box
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEBF8FF), // Light blue info box
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBE1FA)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF1E88E5)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Before Publishing', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                        SizedBox(height: 4),
                        Text('Make sure to review your announcement carefully. All active users will receive this notification.', style: TextStyle(color: Color(0xFF1976D2), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Publish Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _saveAnnouncement(status: 'published'),
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, size: 18),
                label: Text(_isLoading ? 'Publishing...' : 'Publish Announcement', style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCFD8DC),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFCFD8DC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Back Button
            SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                  // Optionally prompt to save as draft if fields are filled
                  if (_titleController.text.isNotEmpty || _messageController.text.isNotEmpty) {
                    _saveAnnouncement(status: 'draft');
                  } else {
                    Navigator.pop(context);
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                  foregroundColor: const Color(0xFF424242),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Back', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}