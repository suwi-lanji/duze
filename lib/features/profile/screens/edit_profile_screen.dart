import 'package:duze/features/auth/providers/auth_provider.dart';
import 'package:duze/shared/widgets/custom_app_bar.dart';
import 'package:duze/shared/widgets/app_colors.dart';
import 'package:duze/shared/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  File? _selectedImage;
  double _visibilityRadius = 5.0;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    _displayNameController = TextEditingController(text: user?.displayName ?? '');
    _visibilityRadius = user?.visibilityRadius ?? 5.0;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile(AuthProvider authProvider) async {
    if (_formKey.currentState!.validate()) {
      try {
        final updates = {
          'displayName': _displayNameController.text.trim(),
          'visibilityRadius': _visibilityRadius,
        };
        if (_selectedImage != null) {
          final photoURL = await authProvider.uploadProfileImage(_selectedImage! );
          if (photoURL != null) {
            updates['photoURL'] = photoURL;
          }
        }
        await authProvider.updateUserProfile(updates);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update profile: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: const CustomAppBar(),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.profileGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: _selectedImage != null
                                ? FileImage(_selectedImage!)
                                : user!.photoURL.isNotEmpty
                                    ? NetworkImage(user!.photoURL)
                                    : null,
                            child: _selectedImage == null && (user?.photoURL.isEmpty ?? true)
                                ? const Icon(Icons.person, size: 50, color: AppColors.grey600)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryTeal,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 20, color: AppColors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Display Name',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _displayNameController,
                    decoration: InputDecoration(
                      hintText: 'Enter your name',
                      filled: true,
                      fillColor: AppColors.white.withOpacity(0.9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(fontFamily: 'Poppins', color: AppColors.textDark),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Visibility Radius',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_visibilityRadius.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: AppColors.grey600,
                        ),
                      ),
                      Slider(
                        value: _visibilityRadius,
                        min: 1.0,
                        max: 10.0,
                        divisions: 90,
                        activeColor: AppColors.primaryTeal,
                        inactiveColor: AppColors.grey600,
                        label: '${_visibilityRadius.toStringAsFixed(1)} km',
                        onChanged: (value) {
                          setState(() {
                            _visibilityRadius = value;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Save Changes',
                    gradient: AppColors.buttonGradient,
                    isLoading: authProvider.isLoading,
                    onPressed: () => _saveProfile(authProvider),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}