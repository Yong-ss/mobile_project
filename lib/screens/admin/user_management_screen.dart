import 'package:flutter/material.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  // Mock data for users
  final List<Map<String, dynamic>> _users = [
    {'id': '1', 'name': 'Alice User', 'email': 'alice@example.com', 'role': 'Buyer'},
    {'id': '2', 'name': 'Bob Seller', 'email': 'bob@example.com', 'role': 'Seller'},
    {'id': '3', 'name': 'Charlie Buyer', 'email': 'charlie@example.com', 'role': 'Buyer'},
  ];

  void _deleteUser(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${_users[index]['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _users.removeAt(index);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User deleted successfully')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editUser(int index) {
    final TextEditingController nameController = TextEditingController(text: _users[index]['name']);
    final TextEditingController emailController = TextEditingController(text: _users[index]['email']);
    String selectedRole = _users[index]['role'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: ['Buyer', 'Seller'].map((role) {
                  return DropdownMenuItem(value: role, child: Text(role));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedRole = value;
                  }
                },
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
              setState(() {
                _users[index]['name'] = nameController.text;
                _users[index]['email'] = emailController.text;
                _users[index]['role'] = selectedRole;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User updated successfully')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
      ),
      body: _users.isEmpty
          ? const Center(child: Text('No users found.'))
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: user['role'] == 'Seller' ? Colors.orange : Colors.lightBlue,
                      child: Icon(
                        user['role'] == 'Seller' ? Icons.store : Icons.person,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(user['name']),
                    subtitle: Text('${user['email']}\nRole: ${user['role']}'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.lightBlue),
                          onPressed: () => _editUser(index),
                          tooltip: 'Edit User',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteUser(index),
                          tooltip: 'Delete User',
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
