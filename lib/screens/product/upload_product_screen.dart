import 'package:flutter/material.dart';
import '../../utils/globals.dart';
import '../../utils/snackbar_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Member 4: Upload Product screen — Placeholder for camera feature (Ch 3.1: Placeholder)

class UploadProductScreen extends StatefulWidget {
  const UploadProductScreen({super.key});

  @override
  State<UploadProductScreen> createState() => _UploadProductScreenState();
}

class _UploadProductScreenState extends State<UploadProductScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  final _supabase = Supabase.instance.client;
  String uid = currentUser!['id'];

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  bool _isLoading = false;
  
  Future<void> submitProduct() async {
    final name = _nameController.text.trim();
    final price = _priceController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty || price.isEmpty || _selectedCategory == null) {
      snackbar('Please fill all required fields', Colors.orange);
      return;
    }

    final parsedPrice = double.tryParse(price);
    if (parsedPrice == null) {
      snackbar('Invalid price format', Colors.red);
      return;
    }

    try {
      setState(() => _isLoading = true);

      await _supabase.from('product').insert({
        'name': name,
        'price': parsedPrice,
        'description': description,
        'category': _selectedCategory,
        'seller_id': uid,
        'for_sale': true,
      });

      if (mounted) {
        setState(() => _isLoading = false);
        snackbar('Product uploaded successfully!', Colors.green);
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
      appBar: AppBar(title: const Text('Upload Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Camera placeholder area (will be replaced with real camera in later phase)
            const Text('Product Photo',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 200,
              // Placeholder widget recommended by Ch 3.1 for in-development areas
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Placeholder(),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                      const SizedBox(height: 4),
                      const Text('Tap to take photo',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {}, // Camera logic added later
                        child: const Text('Open Camera'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Product Name
            const Text('Product Name',
                style: TextStyle(fontWeight: FontWeight.bold)),
                
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g. Bluetooth Speaker',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Price
            const Text('Price (RM)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g. 60.00',
                border: OutlineInputBorder(),
                prefixText: 'RM ',
              ),
            ),
            const SizedBox(height: 16),

            // Category
            const Text('Category',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                hintText: 'Select a category',
                border: OutlineInputBorder(),
              ),
              items: shopCategories
                  .where((cat) => cat != 'All') // 上传商品时不能选 "All"
                  .map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue;
                });
              },
            ),
            const SizedBox(height: 16),

            // Description
            const Text('Description',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Describe your product...',
                border: OutlineInputBorder(),
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
                    : const Text(
                        'Submit Listing',
                        style: TextStyle(
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
