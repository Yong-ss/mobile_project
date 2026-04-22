import 'package:flutter/material.dart';
import '../../utils/globals.dart';
import '../../utils/snackbar_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/translations.dart';

// Member 4: Upload Product screen — Placeholder for camera feature (Ch 3.1: Placeholder)

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
  String? _newImageUrl;
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
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(t('take_photo')),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final userId = currentUser!['id'];
      final path = 'products/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await image.readAsBytes();

      await _supabase.storage.from('products').uploadBinary(path, bytes);
      final String imageUrl = _supabase.storage.from('products').getPublicUrl(path);

      setState(() {
        _newImageUrl = imageUrl;
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
        'image_url': _newImageUrl,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('upload_product'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _isInitialLoading
            ? const _LocalUploadProductSkeleton()
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('product_photo'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.blue.shade50,
                      backgroundImage: _newImageUrl != null ? NetworkImage(_newImageUrl!) : null,
                      child: (_newImageUrl == null)
                          ? const Icon(Icons.inventory, size: 60, color: Colors.lightBlue)
                          : null,
                    ),
                    if (_isUploading)
                      const Positioned.fill(
                        child: Center(child: CircularProgressIndicator(strokeWidth: 4, color: Colors.white)),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        backgroundColor: Colors.lightBlue,
                        radius: 20,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          onPressed: _showImageSourceDialog,
                        ),
                      ),
                    ),
                  ],
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
              Text(t('for_sale_active'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Switch(value: _forSale, onChanged: (value) => setState(() => _forSale = value)),
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
          const Center(child: ContainerSkeleton(width: 120, height: 120, borderRadius: 60)),
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
