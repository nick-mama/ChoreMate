import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../core/services/notification_service.dart';
import '../../features/account/pages/notifications_page.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: NotificationService.instance.hasUnreadNotificationsStream(),
      builder: (context, snapshot) {
        final has = snapshot.data == true;

        return IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            );
          },
          icon: Icon(
            has
                ? Icons.notifications_rounded
                : Icons.notifications_none_rounded,
            size: 38,
            color: has ? AppColors.blue : Colors.black,
          ),
        );
      },
    );
  }
}
