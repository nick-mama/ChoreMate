class AppNotification {
  final String id;
  final String userId;
  final String householdId;
  final String type;
  final String title;
  final String body;
  final String? choreId;
  final bool read;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.householdId,
    required this.type,
    required this.title,
    required this.body,
    this.choreId,
    required this.read,
    this.createdAt,
  });

  String get createdAtText {
    if (createdAt == null) return '';

    final now = DateTime.now();
    final difference = now.difference(createdAt!);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${createdAt!.month}/${createdAt!.day}/${createdAt!.year}';
  }

  factory AppNotification.fromFirestore(String id, Map<String, dynamic> data) {
    return AppNotification(
      id: id,
      userId: data['userId'] ?? '',
      householdId: data['householdId'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      choreId: data['choreId'],
      read: data['read'] ?? false,
      createdAt: data['createdAt']?.toDate(),
    );
  }
}

class NotificationSettings {
  final bool newChoreAssigned;
  final bool overdueChores;
  final bool upcomingDeadlines;
  final bool newPeopleAdded;
  final bool inApp;
  final bool email;
  final bool banner;

  const NotificationSettings({
    this.newChoreAssigned = true,
    this.overdueChores = true,
    this.upcomingDeadlines = true,
    this.newPeopleAdded = true,
    this.inApp = true,
    this.email = false,
    this.banner = true,
  });

  factory NotificationSettings.fromMap(dynamic data) {
    final map = data is Map ? data : {};

    return NotificationSettings(
      newChoreAssigned: map['newChoreAssigned'] ?? true,
      overdueChores: map['overdueChores'] ?? true,
      upcomingDeadlines: map['upcomingDeadlines'] ?? true,
      newPeopleAdded: map['newPeopleAdded'] ?? true,
      inApp: map['inApp'] ?? true,
      email: map['email'] ?? false,
      banner: map['banner'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'newChoreAssigned': newChoreAssigned,
      'overdueChores': overdueChores,
      'upcomingDeadlines': upcomingDeadlines,
      'newPeopleAdded': newPeopleAdded,
      'inApp': inApp,
      'email': email,
      'banner': banner,
    };
  }
}
