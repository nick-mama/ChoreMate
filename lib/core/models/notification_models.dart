import 'package:cloud_firestore/cloud_firestore.dart';

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

  const AppNotification({
    required this.id,
    required this.userId,
    required this.householdId,
    required this.type,
    required this.title,
    required this.body,
    required this.choreId,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(String id, Map<String, dynamic> data) {
    return AppNotification(
      id: id,
      userId: data['userId'] ?? '',
      householdId: data['householdId'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? 'Notification',
      body: data['body'] ?? '',
      choreId: data['choreId'],
      read: data['read'] == true,
      createdAt: _readDate(data['createdAt']),
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String get createdAtText {
    if (createdAt == null) return '';

    final hour = createdAt!.hour == 0
        ? 12
        : createdAt!.hour > 12
        ? createdAt!.hour - 12
        : createdAt!.hour;

    final minute = createdAt!.minute.toString().padLeft(2, '0');
    final period = createdAt!.hour >= 12 ? 'pm' : 'am';

    return '${createdAt!.month}/${createdAt!.day}/${createdAt!.year}, $hour:$minute$period';
  }
}

class NotificationSettings {
  final bool newChoreAssigned;
  final bool overdueChores;
  final bool upcomingDeadlines;
  final bool newHouseholdMembers;
  final bool inApp;
  final bool email;
  final bool banner;

  const NotificationSettings({
    required this.newChoreAssigned,
    required this.overdueChores,
    required this.upcomingDeadlines,
    required this.newHouseholdMembers,
    required this.inApp,
    required this.email,
    required this.banner,
  });

  factory NotificationSettings.defaults() {
    return const NotificationSettings(
      newChoreAssigned: true,
      overdueChores: true,
      upcomingDeadlines: true,
      newHouseholdMembers: true,
      inApp: true,
      email: false,
      banner: true,
    );
  }

  factory NotificationSettings.fromMap(Map<String, dynamic>? data) {
    final d = NotificationSettings.defaults();
    if (data == null) return d;

    return NotificationSettings(
      newChoreAssigned: data['newChoreAssigned'] ?? d.newChoreAssigned,
      overdueChores: data['overdueChores'] ?? d.overdueChores,
      upcomingDeadlines: data['upcomingDeadlines'] ?? d.upcomingDeadlines,
      newHouseholdMembers: data['newHouseholdMembers'] ?? d.newHouseholdMembers,
      inApp: data['inApp'] ?? d.inApp,
      email: data['email'] ?? d.email,
      banner: data['banner'] ?? d.banner,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'newChoreAssigned': newChoreAssigned,
      'overdueChores': overdueChores,
      'upcomingDeadlines': upcomingDeadlines,
      'newHouseholdMembers': newHouseholdMembers,
      'inApp': inApp,
      'email': email,
      'banner': banner,
    };
  }

  NotificationSettings copyWith({
    bool? newChoreAssigned,
    bool? overdueChores,
    bool? upcomingDeadlines,
    bool? newHouseholdMembers,
    bool? inApp,
    bool? email,
    bool? banner,
  }) {
    return NotificationSettings(
      newChoreAssigned: newChoreAssigned ?? this.newChoreAssigned,
      overdueChores: overdueChores ?? this.overdueChores,
      upcomingDeadlines: upcomingDeadlines ?? this.upcomingDeadlines,
      newHouseholdMembers: newHouseholdMembers ?? this.newHouseholdMembers,
      inApp: inApp ?? this.inApp,
      email: email ?? this.email,
      banner: banner ?? this.banner,
    );
  }
}
