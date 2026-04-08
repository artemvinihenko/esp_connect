import 'package:flutter/material.dart';

enum StatusType { info, success, error, warning }

class StatusCard extends StatelessWidget {
  final String message;
  final StatusType type;
  final bool isLoading;
  
  const StatusCard({
    super.key,
    required this.message,
    this.type = StatusType.info,
    this.isLoading = false,
  });
  
  @override
  Widget build(BuildContext context) {
    Color getColor() {
      switch (type) {
        case StatusType.success:
          return Colors.green;
        case StatusType.error:
          return Colors.red;
        case StatusType.warning:
          return Colors.orange;
        default:
          return Colors.blue;
      }
    }
    
    IconData getIcon() {
      if (isLoading) return Icons.hourglass_empty;
      switch (type) {
        case StatusType.success:
          return Icons.check_circle;
        case StatusType.error:
          return Icons.error;
        case StatusType.warning:
          return Icons.warning;
        default:
          return Icons.info_outline;
      }
    }
    
    return Card(
      color: getColor().withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(getIcon(), color: getColor()),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}