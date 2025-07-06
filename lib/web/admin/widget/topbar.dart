import 'package:flutter/material.dart';
class CustomTopBar extends StatefulWidget {
  final String title;
  final String? subtitle;

  const CustomTopBar({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  State<CustomTopBar> createState() => _CustomTopBarState();
}

class _CustomTopBarState extends State<CustomTopBar> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (widget.subtitle == null)
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Row(
              children: [
                MouseRegion(
                  onEnter: (_) => setState(() => isHovered = true),
                  onExit: (_) => setState(() => isHovered = false),
                  child: InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(4),
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        decoration:
                        isHovered ? TextDecoration.underline : TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.chevron_right, color: Colors.grey),
                const SizedBox(width: 10),
                Text(
                  widget.subtitle!,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

          const Spacer(),
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

