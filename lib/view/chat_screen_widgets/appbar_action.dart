import 'package:flutter/material.dart';

Widget buildAppBarAction(IconData icon, VoidCallback onPressed) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 4),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
            ),
          ),
          child: Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
        ),
      ),
    ),
  );
}
