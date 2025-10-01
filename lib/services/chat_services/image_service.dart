import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

  final ImagePicker _picker = ImagePicker();

  Future<bool> _requestCameraPermission() async {
    final cameraStatus = await Permission.camera.request();
    return cameraStatus.isGranted;
  }

  Future<bool> _requestGalleryPermission() async {
    // iOS requires Photos permission; Android commonly doesn't require storage for system picker
    if (Platform.isIOS) {
      final photos = await Permission.photos.request();
      return photos.isGranted;
    }
    // On Android, try without explicit permission; if your target API requires it, you can request here.
    return true;
  }

  Future<File?> pickImageFromCamera() async {
    try {
      if (!await _requestCameraPermission()) {
        Get.snackbar(
          'Permission Required',
          'Camera permission is required',
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
        return null;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1080,
        maxHeight: 1080,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to capture image: $e',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return null;
    }
  }

  Future<File?> pickImageFromGallery() async {
    try {
      if (!await _requestGalleryPermission()) {
        Get.snackbar(
          'Permission Required',
          'Photos permission is required',
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
        return null;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1080,
        maxHeight: 1080,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick image: $e',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return null;
    }
  }

  Future<File?> showImageSourceDialog() async {
    final ctx = Get.context;
    if (ctx == null) return null;

    final String? choice = await showModalBottomSheet<String>(
      context: ctx,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Camera', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(context).pop('camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Gallery', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(context).pop('gallery'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (choice == 'camera') {
      return await pickImageFromCamera();
    } else if (choice == 'gallery') {
      return await pickImageFromGallery();
    }
    return null;
  }


}