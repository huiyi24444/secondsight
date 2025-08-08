// File: lib/widgets/view_details_link.dart
import 'package:flutter/material.dart';

class ViewDetailsLink extends StatefulWidget {
  final VoidCallback onTap;
  final String? text;
  final double? fontSize;
  final Color? textColor;
  final EdgeInsetsGeometry? padding;
  final bool showArrow;
  final double? arrowSize;

  const ViewDetailsLink({
    Key? key,
    required this.onTap,
    this.text = 'View Details',
    this.fontSize = 12,
    this.textColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.showArrow = true,
    this.arrowSize = 12,
  }) : super(key: key);

  @override
  State<ViewDetailsLink> createState() => _ViewDetailsLinkState();
}

class _ViewDetailsLinkState extends State<ViewDetailsLink> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = widget.textColor ?? Theme.of(context).primaryColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: widget.padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.text!,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  color: effectiveTextColor,
                  fontWeight: FontWeight.w500,
                  decoration: isHovered ? TextDecoration.underline : TextDecoration.none,
                  decorationColor: effectiveTextColor,
                ),
              ),
              if (widget.showArrow) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: widget.arrowSize,
                  color: effectiveTextColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}