import 'package:flutter/material.dart';

class CustomTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String badgeText;

  const CustomTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.badgeText = 'All Shop',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (subtitle == null)
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.chevron_right),
                const SizedBox(width: 10),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              badgeText,
              style: TextStyle(color: Colors.orange[800]),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.notifications_outlined),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            child: const Icon(Icons.person, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
