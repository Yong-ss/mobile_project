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
  final _quantityController = TextEditingController(); // Added
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  final _supabase = Supabase.instance.client;
  String uid = currentUser!['id'];
  bool _isLoading = false;
  String? _newImageUrl;
  bool _isUploading = false;
  bool _forSale = true; // Added

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
    // based on the source (gallery or camera) select image
    final XFile? image = await picker.pickImage(source: source);

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final userId = currentUser!['id'];
      final path =
          'products/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await image.readAsBytes();

      await _supabase.storage.from('products').uploadBinary(path, bytes);
      final String imageUrl = _supabase.storage
          .from('products')
          .getPublicUrl(path);

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

    if (name.isEmpty ||
        priceStr.isEmpty ||
        quantityStr.isEmpty ||
        _selectedCategory == null) {
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
      appBar: AppBar(title: Text(t('upload_product'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Camera placeholder area (will be replaced with real camera in later phase)
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
                    backgroundImage: _newImageUrl != null
                        ? NetworkImage(_newImageUrl!)
                        : null,
                    child: (_newImageUrl == null)
                        ? const Icon(
                      Icons.inventory,
                      size: 60,
                      color: Colors.lightBlue,
                    )
                        : null,
                  ),

                  if (_isUploading)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          color: Colors.white,
                        ),
                      ),
                    ),

                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.lightBlue,
                      radius: 20,
                      child: IconButton(
                        icon: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: _showImageSourceDialog,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            const SizedBox(height: 20),

            // Product Name
            Text(
              t('product_name'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: t('hint_product_name'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Price
            Text(
              t('price_rm'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: t('hint_price'),
                border: const OutlineInputBorder(),
                prefixText: 'RM ',
              ),
            ),
            const SizedBox(height: 16),

            // Category
            Text(
              t('category'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                hintText: t('hint_select_category'),
                border: const OutlineInputBorder(),
              ),
              items: shopCategories
                  .where((cat) => cat != 'All') // 上传商品时不能选 "All"
                  .map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              })
                  .toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue;
                });
              },
            ),
            const SizedBox(height: 16),

            // Quantity
            Text(
              t('quantity'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: t('hint_quantity'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // For Sale
            Text(
              t('for_sale_active'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Switch(
              value: _forSale,
              onChanged: (value) {
                setState(() {
                  _forSale = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              t('description'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: t('hint_description'),
                border: const OutlineInputBorder(),
              ),
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
                  // set height to 55, width adaptive
                  minimumSize: const Size(double.infinity, 55),
                  // set more modern rounded corners
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 2, //enchance shadow
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  t('submit_listing'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1, //enchance letter spacing
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