import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/profile_controller.dart';

class GlassInfoCard extends StatelessWidget {
  final String label;
  final RxString value;
  final ProfileController controller;
  final String fieldName;
  final TextEditingController? textController;
  final bool isEditable;

  const GlassInfoCard({
    super.key,
    required this.label,
    required this.value,
    required this.controller,
    required this.fieldName,
    this.textController,
    this.isEditable = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.9, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.25),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (!isEditable)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Icon(
                                      Icons.lock,
                                      size: 12,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Use Obx to make the entire field reactive
                            Obx(() {
                              // Show TextFormField only if editing is enabled and field is editable
                              if (controller.isEditing.value &&
                                  isEditable &&
                                  textController != null) {
                                return TextFormField(
                                  controller: textController,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: 'Enter $label',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 16,
                                    ),
                                  ),
                                  validator: (val) {
                                    if (fieldName == 'name' &&
                                        (val == null || val.trim().isEmpty)) {
                                      return 'Name is required';
                                    }
                                    return null;
                                  },
                                  onChanged: (val) {
                                    // Update the reactive value
                                    value.value = val;
                                    controller.markChanged();

                                    // Update specific controller fields
                                    switch (fieldName) {
                                      case 'name':
                                        controller.name.value = val;
                                        break;
                                      case 'bio':
                                        controller.bio.value = val;
                                        break;
                                      case 'status':
                                        controller.status.value = val;
                                        break;
                                    }
                                  },
                                );
                              } else {
                                // Show read-only text
                                return Text(
                                  value.value.isEmpty ? 'Not set' : value.value,
                                  style: TextStyle(
                                    color: value.value.isEmpty
                                        ? Colors.grey[400]
                                        : Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    fontStyle: value.value.isEmpty
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                );
                              }
                            }),
                          ],
                        ),
                      ),
                      // Show edit indicator for editable fields
                      if (isEditable)
                        Obx(() => controller.isEditing.value
                            ? Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.blue[300],
                        )
                            : Icon(
                          Icons.edit_off,
                          size: 16,
                          color: Colors.grey[400],
                        )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.8, end: 1.0),
      curve: Curves.easeOutBack,
      child: child,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Padding(
                padding: padding ?? const EdgeInsets.all(10),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
