import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/globals.dart';
import '../../utils/snackbar_helper.dart';
import 'package:image_picker/image_picker.dart';

class EditProductScreen extends StatefulWidget {
  final Map<String, dynamic> product; // 需要传入要编辑的商品数据
  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  final _supabase = Supabase.instance.client;
  String uid = currentUser!['id'];
  bool _isLoading = false;
  String? _newImageUrl;
  bool _isUploading = false;
  bool _forSale = true;

  @override
  void initState() {
    super.initState();
    // 初始化数据填充按钮
    _nameController.text = widget.product['name'] ?? '';
    _priceController.text = widget.product['price']?.toString() ?? '';
    _quantityController.text = widget.product['quantity']?.toString() ?? '';
    _descriptionController.text = widget.product['description'] ?? '';
    _selectedCategory = widget.product['category'];
    _newImageUrl = widget.product['image_url'];
    _forSale = widget.product['for_sale'] ?? true;
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
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
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
      snackbar('Upload error: $e', Colors.red);
    }
  }

  Future<void> updateProduct() async {
    final name = _nameController.text.trim();
    final priceStr = _priceController.text.trim();
    final quantityStr = _quantityController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty || priceStr.isEmpty || quantityStr.isEmpty || _selectedCategory == null) {
      snackbar('Please fill all required fields', Colors.orange);
      return;
    }

    final price = double.tryParse(priceStr);
    if (price == null) {
      snackbar('Invalid price format', Colors.red);
      return;
    }

    final quantity = int.tryParse(quantityStr);
    if (quantity == null) {
      snackbar('Invalid quantity format', Colors.red);
      return;
    }

    try {
      setState(() => _isLoading = true);

      await _supabase.from('product').update({
        'name': name,
        'price': price,
        'quantity': quantity,
        'description': description,
        'category': _selectedCategory,
        'for_sale': _forSale,
        'image_url': _newImageUrl,
      }).eq('id', widget.product['id']); // 重要：指定更新哪个商品

      if (mounted) {
        setState(() => _isLoading = false);
        snackbar('Product updated successfully!', Colors.green);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        snackbar('Error: $e', Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Edit Product', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Product Photo', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 65,
                    backgroundColor: Colors.blue.shade50,
                    backgroundImage: _newImageUrl != null ? NetworkImage(_newImageUrl!) : null,
                    child: (_newImageUrl == null)
                        ? const Icon(Icons.inventory, size: 60, color: Colors.lightBlue)
                        : null,
                  ),
                  if (_isUploading)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 4, color: Colors.white),
                      ),
                    ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.blue,
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

            const Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'e.g. Vintage Camera',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            const Text('Price (RM)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'e.g. 150.00',
                border: OutlineInputBorder(),
                prefixText: 'RM ',
              ),
            ),
            const SizedBox(height: 16),

            const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                hintText: 'Select a category',
                border: OutlineInputBorder(),
              ),
              items: shopCategories.where((cat) => cat != 'All').map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() => _selectedCategory = newValue);
              },
            ),
            const SizedBox(height: 16),

            const Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'e.g. 10',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('For Sale / Active', style: TextStyle(fontWeight: FontWeight.bold)),
                Switch(
                  value: _forSale,
                  activeColor: Colors.blue,
                  onChanged: (value) => setState(() => _forSale = value),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Describe your product...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : updateProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}