import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/notification_models.dart';
import '../../../core/services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<AppNotification> _lastNotifications = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.text,
          ),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: NotificationService.instance.markAllAsRead,
            child: const Text(
              'Mark all read',
              style: TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<AppNotification>>(
          stream: NotificationService.instance.notificationsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _EmptyNotificationsState(
                title: 'Could not load notifications.',
                subtitle: 'Check your Firestore rules or indexes.',
                icon: Icons.error_outline_rounded,
              );
            }

            if (snapshot.hasData) {
              _lastNotifications = snapshot.data!;
            }

            final notifications = _lastNotifications;

            if (snapshot.connectionState == ConnectionState.waiting &&
                notifications.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (notifications.isEmpty) {
              return const _EmptyNotificationsState(
                title: 'No notifications yet.',
                subtitle:
                    'Chore updates and household alerts will show up here.',
                icon: Icons.notifications_none_rounded,
              );
            }

            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                28 + MediaQuery.of(context).padding.bottom,
              ),
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _NotificationTile(notification: notifications[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      onDismissed: (_) {
        NotificationService.instance.deleteNotification(notification.id);
      },
      child: Material(
        color: unread ? AppColors.cream : AppColors.field,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => NotificationService.instance.markAsRead(notification.id),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: unread ? AppColors.blue : AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconForType(notification.type),
                    size: 22,
                    color: unread ? Colors.white : AppColors.muted,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        notification.body,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          color: AppColors.text,
                        ),
                      ),
                      if (notification.createdAtText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          notification.createdAtText,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'newChoreAssigned':
        return Icons.assignment_outlined;
      case 'overdueChore':
        return Icons.warning_amber_rounded;
      case 'upcomingDeadline':
        return Icons.event_available_outlined;
      case 'newHouseholdMember':
        return Icons.person_add_alt_1_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}

class _EmptyNotificationsState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmptyNotificationsState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
