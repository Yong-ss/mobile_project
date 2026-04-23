import 'package:flutter/material.dart';
import '../../utils/globals.dart';
import '../../utils/snackbar_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/translations.dart';

class UploadProductScreen extends StatefulWidget {
  const UploadProductScreen({super.key});

  @override
  State<UploadProductScreen> createState() => _UploadProductScreenState();
}

class _UploadProductScreenState extends State<UploadProductScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  final _supabase = Supabase.instance.client;
  String uid = currentUser!['id'];
  bool _isLoading = false;
  bool _isInitialLoading = true;

  // Changed to List for multi-image support
  final List<String> _imageUrls = [];
  bool _isUploading = false;
  bool _forSale = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isInitialLoading = false);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(t('choose_gallery')),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImages(); // Gallery supports multi-pick
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(t('take_photo')),
                onTap: () {
                  Navigator.pop(context);
                  _takePhotoAndUpload(); // Camera is single-pick
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Handle Multi-Pick from Gallery
  Future<void> _pickAndUploadImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isEmpty) return;

    setState(() => _isUploading = true);

    try {
      final userId = currentUser!['id'];

      for (var image in images) {
        final path = 'products/$userId/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        final bytes = await image.readAsBytes();

        await _supabase.storage.from('products').uploadBinary(path, bytes);
        final String imageUrl = _supabase.storage.from('products').getPublicUrl(path);

        _imageUrls.add(imageUrl);
      }

      setState(() => _isUploading = false);
    } catch (e) {
      setState(() => _isUploading = false);
      snackbar('${t('upload_error')}: $e', Colors.red);
    }
  }

  // Handle Single-Pick from Camera
  Future<void> _takePhotoAndUpload() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final userId = currentUser!['id'];
      final path = 'products/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await image.readAsBytes();

      await _supabase.storage.from('products').uploadBinary(path, bytes);
      final String imageUrl = _supabase.storage.from('products').getPublicUrl(path);

      setState(() {
        _imageUrls.add(imageUrl);
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      snackbar('${t('upload_error')}: $e', Colors.red);
    }
  }

  Future<void> submitProduct() async {
    final name = _nameController.text.trim();
    final priceStr = _priceController.text.trim();
    final quantityStr = _quantityController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty || priceStr.isEmpty || quantityStr.isEmpty || _selectedCategory == null) {
      snackbar(t('fill_required_fields'), Colors.orange);
      return;
    }

    if (_imageUrls.isEmpty) {
      snackbar(t('please_upload_at_least_one_image'), Colors.orange);
      return;
    }

    final price = double.tryParse(priceStr);
    if (price == null) {
      snackbar(t('invalid_price'), Colors.red);
      return;
    }

    final quantity = int.tryParse(quantityStr);
    if (quantity == null) {
      snackbar(t('invalid_quantity'), Colors.red);
      return;
    }

    try {
      setState(() => _isLoading = true);

      await _supabase.from('product').insert({
        'name': name,
        'price': price,
        'quantity': quantity,
        'description': description,
        'category': _selectedCategory,
        'seller_id': uid,
        'for_sale': _forSale,
        'image_url': _imageUrls.join(','), // Join all URLs with comma
      });

      if (mounted) {
        setState(() => _isLoading = false);
        snackbar(t('product_uploaded'), Colors.green);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        snackbar('${t('error')}: $e', Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? const Color(0xFF212121) : Colors.white,
      child: SafeArea(
        top: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              t('upload_product'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: _isInitialLoading
              ? const _LocalUploadProductSkeleton()
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('product_photos'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),

                // Horizontal Image List
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imageUrls.length + 1,
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      if (index == _imageUrls.length) {
                        // Add Button Card
                        return GestureDetector(
                          onTap: _isUploading ? null : _showImageSourceDialog,
                          child: Container(
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.blue.shade100, width: 2, style: BorderStyle.solid),
                            ),
                            child: _isUploading
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.add_a_photo, color: Colors.blue, size: 30),
                          ),
                        );
                      }

                      // Uploaded Image Card
                      return Stack(
                        children: [
                          Container(
                            width: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                              image: DecorationImage(
                                image: NetworkImage(_imageUrls[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 5,
                            right: 5,
                            child: GestureDetector(
                              onTap: () => setState(() => _imageUrls.removeAt(index)),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),
                Text(t('product_name'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(hintText: t('hint_product_name'), border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Text(t('price_rm'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: t('hint_price'), border: const OutlineInputBorder(), prefixText: 'RM '),
                ),
                const SizedBox(height: 16),
                Text(t('category'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(hintText: t('hint_select_category'), border: const OutlineInputBorder()),
                  items: shopCategories
                      .where((cat) => cat != 'All')
                      .map((String category) => DropdownMenuItem<String>(value: category, child: Text(category)))
                      .toList(),
                  onChanged: (String? newValue) => setState(() => _selectedCategory = newValue),
                ),
                const SizedBox(height: 16),
                Text(t('quantity'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: t('hint_quantity'), border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t('for_sale_active'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    Switch(value: _forSale, onChanged: (value) => setState(() => _forSale = value)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(t('description'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(hintText: t('hint_description'), border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : submitProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text(t('submit_listing'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
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

class _LocalUploadProductSkeleton extends StatelessWidget {
  const _LocalUploadProductSkeleton();
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ContainerSkeleton(width: 100, height: 16),
          const SizedBox(height: 12),
          const SizedBox(
            height: 120,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ContainerSkeleton(width: 100, height: 100, borderRadius: 12),
                  SizedBox(width: 12),
                  ContainerSkeleton(width: 100, height: 100, borderRadius: 12),
                  SizedBox(width: 12),
                  ContainerSkeleton(width: 100, height: 100, borderRadius: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ...List.generate(4, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ContainerSkeleton(width: 80 + (index * 10.0), height: 16),
                const SizedBox(height: 12),
                const ContainerSkeleton(width: double.infinity, height: 56, borderRadius: 12),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class ContainerSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  const ContainerSkeleton({super.key, required this.width, required this.height, this.borderRadius = 8});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}