import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/notification_bell.dart';

class HouseholdPage extends StatefulWidget {
  const HouseholdPage({super.key});

  @override
  State<HouseholdPage> createState() => _HouseholdPageState();
}

class _HouseholdPageState extends State<HouseholdPage> {
  final ScrollController _housematesScrollController = ScrollController();

  String _householdId = '';
  String _householdName = '';
  String _householdType = 'roommates';
  // ignore: unused_field
  String _currentRole = 'member';
  String _startOfWeek = 'sunday';
  bool _loading = true;
  bool overdueExpanded = true;
  bool todoExpanded = true;
  bool completedExpanded = true;

  List<Housemate> housemates = [];
  List<HouseholdActivity> overdueActivities = [];
  List<HouseholdActivity> todoActivities = [];
  List<HouseholdActivity> completedActivities = [];

  @override
  void initState() {
    super.initState();
    _loadHouseholdData();
  }

  @override
  void dispose() {
    _housematesScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHouseholdData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));

    final userData = userDoc.data();
    final householdId = userData?['householdId'] ?? '';
    final startOfWeek = userData?['startOfWeek'] ?? 'sunday';

    if (householdId.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    final householdDoc = await FirebaseFirestore.instance
        .collection('households')
        .doc(householdId)
        .get(const GetOptions(source: Source.server));

    final householdData = householdDoc.data();
    if (householdData == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    final householdName = (householdData['name'] as String?) ?? '';
    final householdType =
        (householdData['householdType'] as String?) ?? 'roommates';

    String currentRole = 'member';
    final roles = householdData['memberRoles'];

    if (roles is Map && roles[user.uid] is String) {
      currentRole = roles[user.uid] as String;
    } else if (householdData['ownerId'] == user.uid ||
        householdData['createdBy'] == user.uid) {
      currentRole = 'owner';
    }

    final loadedHousemates = await _loadHousemates(householdData);
    final loadedActivities = await _loadActivities(householdId);

    if (!mounted) return;
    setState(() {
      _householdId = householdId;
      _householdName = householdName;
      _householdType = householdType;
      _currentRole = currentRole;
      _startOfWeek = startOfWeek;
      housemates = loadedHousemates;
      overdueActivities = loadedActivities.overdue;
      todoActivities = loadedActivities.todo;
      completedActivities = loadedActivities.completed;
      _loading = false;
    });
  }

  Future<List<Housemate>> _loadHousemates(
    Map<String, dynamic> householdData,
  ) async {
    final rawMembers = householdData['members'];
    final memberUids = rawMembers is List
        ? rawMembers.whereType<String>().toList()
        : <String>[];

    final roles = householdData['memberRoles'];
    final loaded = <Housemate>[];

    for (final uid in memberUids) {
      final memberDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));

      final data = memberDoc.data();
      if (data == null) continue;

      final firstName = (data['firstName'] as String?) ?? '';
      final lastName = (data['lastName'] as String?) ?? '';
      final username = (data['username'] as String?) ?? '';
      final photoUrl = (data['photoUrl'] as String?) ?? '';
      final role = roles is Map && roles[uid] is String
          ? roles[uid] as String
          : householdData['ownerId'] == uid || householdData['createdBy'] == uid
          ? 'owner'
          : 'member';

      loaded.add(
        Housemate(
          uid: uid,
          firstName: firstName.isNotEmpty ? firstName : uid,
          lastName: lastName,
          username: username,
          photoUrl: photoUrl,
          role: role,
        ),
      );
    }

    return loaded;
  }

  Future<_HouseholdActivities> _loadActivities(String householdId) async {
    final choresSnapshot = await FirebaseFirestore.instance
        .collection('chores')
        .where('householdId', isEqualTo: householdId)
        .get(const GetOptions(source: Source.server));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final overdue = <HouseholdActivity>[];
    final todo = <HouseholdActivity>[];
    final completed = <HouseholdActivity>[];

    for (final doc in choresSnapshot.docs) {
      final data = doc.data();

      final title = (data['name'] ?? 'Chore').toString();
      final assignedToName = (data['assignedToName'] ?? '').toString();
      final completedBy = assignedToName.isNotEmpty
          ? assignedToName
          : 'Housemate';
      final dueDate = _readDate(data['dueDate']);
      final completedAt = _readDate(data['completedAt']);
      final completedValue = data['completed'] == true;

      if (completedValue) {
        completed.add(
          HouseholdActivity(
            title: title,
            timestamp: _formatDateTime(completedAt),
            details: 'Completed by $completedBy',
            completedBy: completedBy,
            createdAt: _formatDateTime(dueDate),
          ),
        );
      } else {
        final dueDateOnly = dueDate == null
            ? null
            : DateTime(dueDate.year, dueDate.month, dueDate.day);

        final activity = HouseholdActivity(
          title: title,
          timestamp: _formatDate(dueDate),
          details: assignedToName.isNotEmpty
              ? 'Assigned to $assignedToName'
              : 'Unassigned',
          completedBy: assignedToName,
          createdAt: _formatDateTime(dueDate),
        );

        if (dueDateOnly != null && dueDateOnly.isBefore(today)) {
          overdue.add(activity);
        } else {
          todo.add(activity);
        }
      }
    }

    completed.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return _HouseholdActivities(
      overdue: overdue,
      todo: todo,
      completed: completed,
    );
  }

  void _showActivityOverlay(HouseholdActivity activity) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActivityOverlay(activity: activity),
    );
  }

  void _openHousemateProfile(Housemate housemate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HousemateProfilePage(
          housemate: housemate,
          householdId: _householdId,
          startOfWeek: _startOfWeek,
        ),
      ),
    );
  }

  String _householdTypeLabel() {
    return _householdType == 'family' ? 'Family' : 'Roommates';
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.month}/${date.day}/${date.year}';
  }

  static String _formatDateTime(DateTime? date) {
    if (date == null) return '';

    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'pm' : 'am';

    return '${date.month}/${date.day}/${date.year}, $hour:$minute$period';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: _HouseholdHeader(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  28 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Housemates',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    if (_householdName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _householdName,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _householdTypeLabel(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ScrollConfiguration(
                        behavior: const _WebFriendlyScrollBehavior(),
                        child: SizedBox(
                          height: 176,
                          child: Scrollbar(
                            controller: _housematesScrollController,
                            thumbVisibility: true,
                            child: ListView.separated(
                              controller: _housematesScrollController,
                              scrollDirection: Axis.horizontal,
                              itemCount: housemates.length,
                              itemBuilder: (context, index) {
                                return _HousemateCard(
                                  housemate: housemates[index],
                                  onTap: () =>
                                      _openHousemateProfile(housemates[index]),
                                );
                              },
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 18),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    const Text(
                      'Household Chores',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ChoreSectionHeader(
                      title: 'Overdue',
                      expanded: overdueExpanded,
                      onTap: () {
                        setState(() {
                          overdueExpanded = !overdueExpanded;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (overdueExpanded) ...[
                      if (overdueActivities.isEmpty)
                        const _EmptyStateText(text: 'No overdue chores.')
                      else
                        ...overdueActivities.map(
                          (activity) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _HouseholdActivityTile(
                              title: activity.title,
                              timestamp: activity.timestamp,
                              color: AppColors.blue,
                              textColor: Colors.white,
                              timestampColor: Colors.white,
                              onTap: () => _showActivityOverlay(activity),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),
                    _ChoreSectionHeader(
                      title: 'To-Do',
                      expanded: todoExpanded,
                      onTap: () {
                        setState(() {
                          todoExpanded = !todoExpanded;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (todoExpanded) ...[
                      if (todoActivities.isEmpty)
                        const _EmptyStateText(
                          text: 'No chores left. Nice work!',
                        )
                      else
                        ...todoActivities.map(
                          (activity) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _HouseholdActivityTile(
                              title: activity.title,
                              timestamp: activity.timestamp,
                              color: AppColors.blue,
                              textColor: Colors.white,
                              timestampColor: Colors.white,
                              onTap: () => _showActivityOverlay(activity),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),
                    _ChoreSectionHeader(
                      title: 'Completed',
                      expanded: completedExpanded,
                      onTap: () {
                        setState(() {
                          completedExpanded = !completedExpanded;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (completedExpanded) ...[
                      if (completedActivities.isEmpty)
                        const _EmptyStateText(text: 'No completed chores yet.')
                      else
                        ...completedActivities.map(
                          (activity) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _HouseholdActivityTile(
                              title: activity.title,
                              timestamp: activity.timestamp,
                              color: AppColors.field,
                              textColor: AppColors.text,
                              timestampColor: AppColors.muted,
                              onTap: () => _showActivityOverlay(activity),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HousemateProfilePage extends StatefulWidget {
  final Housemate housemate;
  final String householdId;
  final String startOfWeek;

  const HousemateProfilePage({
    super.key,
    required this.housemate,
    required this.householdId,
    required this.startOfWeek,
  });

  @override
  State<HousemateProfilePage> createState() => _HousemateProfilePageState();
}

class _HousemateProfilePageState extends State<HousemateProfilePage> {
  bool _loading = true;

  List<double> weeklyValues = [0, 0, 0, 0];
  List<String> weekLabels = ['', '', '', ''];
  List<HouseholdActivity> choreHistory = [];

  int choresDone = 0;
  int totalChores = 0;
  int uniqueChores = 0;
  int maxChoresInAWeek = 0;
  int choreStreak = 0;

  @override
  void initState() {
    super.initState();
    _loadHousemateData();
  }

  Future<void> _loadHousemateData() async {
    final emptyData = _emptyHousemateData();

    if (widget.householdId.isEmpty || widget.housemate.uid.isEmpty) {
      if (!mounted) return;
      setState(() {
        weeklyValues = emptyData.weeklyValues;
        weekLabels = emptyData.weekLabels;
        _loading = false;
      });
      return;
    }

    final choresSnapshot = await FirebaseFirestore.instance
        .collection('chores')
        .where('householdId', isEqualTo: widget.householdId)
        .get(const GetOptions(source: Source.server));

    final uniqueNames = <String>{};
    final completedWeeks = <DateTime>{};
    final history = <HouseholdActivity>[];

    var completedCount = 0;
    var assignedCount = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekStart = _startOfWeekFor(today, widget.startOfWeek);
    final firstWeekStart = currentWeekStart.subtract(const Duration(days: 21));
    final lastWeekEnd = currentWeekStart.add(const Duration(days: 7));

    final weeklyCounts = List<double>.filled(4, 0);

    for (final doc in choresSnapshot.docs) {
      final data = doc.data();

      if (data['assignedTo'] != widget.housemate.uid) continue;

      assignedCount += 1;

      final name = (data['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        uniqueNames.add(name.toLowerCase());
      }

      if (data['completed'] != true) continue;

      completedCount += 1;

      final completedAt = _readDate(data['completedAt']);
      if (completedAt == null) continue;

      final completedDate = DateTime(
        completedAt.year,
        completedAt.month,
        completedAt.day,
      );

      final weekStart = _startOfWeekFor(completedDate, widget.startOfWeek);

      completedWeeks.add(
        DateTime(weekStart.year, weekStart.month, weekStart.day),
      );

      history.add(
        HouseholdActivity(
          title: name.isNotEmpty ? name : 'Chore',
          timestamp: _formatDateTime(completedAt),
          details: 'Completed by ${widget.housemate.firstName}',
          completedBy: widget.housemate.firstName,
          createdAt: _formatDateTime(_readDate(data['dueDate'])),
        ),
      );

      if (completedDate.isBefore(firstWeekStart) ||
          !completedDate.isBefore(lastWeekEnd)) {
        continue;
      }

      final weekIndex = completedDate.difference(firstWeekStart).inDays ~/ 7;
      if (weekIndex < 0 || weekIndex > 3) continue;

      weeklyCounts[weekIndex] += 1;
    }

    final maxWeeklyChores = weeklyCounts.isEmpty
        ? 0
        : weeklyCounts.reduce((a, b) => a > b ? a : b).toInt();

    history.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (!mounted) return;
    setState(() {
      weeklyValues = weeklyCounts;
      weekLabels = emptyData.weekLabels;
      choreHistory = history;
      choresDone = completedCount;
      totalChores = assignedCount;
      uniqueChores = uniqueNames.length;
      maxChoresInAWeek = maxWeeklyChores;
      choreStreak = completedWeeks.length;
      _loading = false;
    });
  }

  _HousemateData _emptyHousemateData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekStart = _startOfWeekFor(today, widget.startOfWeek);
    final firstWeekStart = currentWeekStart.subtract(const Duration(days: 21));

    final labels = List.generate(4, (index) {
      final weekStart = firstWeekStart.add(Duration(days: index * 7));
      return '${_shortMonthName(weekStart.month)} ${weekStart.day}';
    });

    return _HousemateData(
      weeklyValues: List<double>.filled(4, 0),
      weekLabels: labels,
    );
  }

  DateTime _startOfWeekFor(DateTime date, String startOfWeek) {
    final normalized = DateTime(date.year, date.month, date.day);

    if (startOfWeek == 'monday') {
      return normalized.subtract(Duration(days: normalized.weekday - 1));
    }

    return normalized.subtract(Duration(days: normalized.weekday % 7));
  }

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return '';

    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'pm' : 'am';

    return '${date.month}/${date.day}/${date.year}, $hour:$minute$period';
  }

  String _shortMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 26,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AppLogo(type: LogoType.wordmark, width: 200),
                    ),
                  ),
                  const NotificationBell(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  28,
                  20,
                  28 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HousemateProfileSection(housemate: widget.housemate),
                    const SizedBox(height: 26),
                    const Text(
                      'Chores Completed',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Individual',
                      style: TextStyle(fontSize: 16, color: AppColors.text),
                    ),
                    const SizedBox(height: 14),
                    _BarChartCard(values: weeklyValues, labels: weekLabels),
                    const SizedBox(height: 26),
                    const Text(
                      'Chore History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (choreHistory.isEmpty)
                      const Text(
                        'No chores recorded yet.',
                        style: TextStyle(fontSize: 15, color: AppColors.muted),
                      )
                    else
                      ...choreHistory.map(
                        (activity) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _HousemateActivityTile(activity: activity),
                        ),
                      ),
                    const SizedBox(height: 26),
                    const Text(
                      'Account Stats',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _HousemateStatsGrid(
                      choresDone: choresDone,
                      totalChores: totalChores,
                      uniqueChores: uniqueChores,
                      maxChoresInAWeek: maxChoresInAWeek,
                      choreStreak: choreStreak,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HouseholdHeader extends StatelessWidget {
  const _HouseholdHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppLogo(type: LogoType.wordmark, width: 230),
          ),
        ),
        const NotificationBell(),
      ],
    );
  }
}

class _ChoreSectionHeader extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onTap;

  const _ChoreSectionHeader({
    required this.title,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: AppColors.muted,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _HousemateCard extends StatelessWidget {
  final Housemate housemate;
  final VoidCallback onTap;

  const _HousemateCard({required this.housemate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 125,
        child: Column(
          children: [
            ProfileAvatar(photoUrl: housemate.photoUrl, size: 106),
            const SizedBox(height: 10),
            Text(
              housemate.firstName,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (housemate.username.isNotEmpty)
              Text(
                '@${housemate.username}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            Text(
              housemate.roleLabel,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _HouseholdActivityTile extends StatelessWidget {
  final String title;
  final String timestamp;
  final Color color;
  final Color textColor;
  final Color timestampColor;
  final VoidCallback onTap;

  const _HouseholdActivityTile({
    required this.title,
    required this.timestamp,
    required this.color,
    required this.textColor,
    required this.timestampColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                timestamp,
                style: TextStyle(fontSize: 14, color: timestampColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStateText extends StatelessWidget {
  final String text;

  const _EmptyStateText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, color: AppColors.muted),
      ),
    );
  }
}

class _ActivityOverlay extends StatelessWidget {
  final HouseholdActivity activity;

  const _ActivityOverlay({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    activity.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _OverlayField('Status:', activity.details),
            _OverlayField('Created:', activity.createdAt),
            _OverlayField('Date:', activity.timestamp),
          ],
        ),
      ),
    );
  }
}

class _OverlayField extends StatelessWidget {
  final String label;
  final String value;

  const _OverlayField(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 15),
          children: [
            TextSpan(
              text: '$label\n',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value.isNotEmpty ? value : 'Not available'),
          ],
        ),
      ),
    );
  }
}

class _HousemateProfileSection extends StatelessWidget {
  final Housemate housemate;

  const _HousemateProfileSection({required this.housemate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileAvatar(
              photoUrl: housemate.photoUrl,
              size: 120,
              borderWidth: 8,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      housemate.fullName,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  if (housemate.username.isNotEmpty)
                    Text(
                      '@${housemate.username}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.muted,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    housemate.roleLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ProfileActionButton(
                icon: Icons.ios_share_outlined,
                label: 'Invite',
                onTap: () {},
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(child: _PrivacyBadgeButton()),
          ],
        ),
      ],
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.tan,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _PrivacyBadgeButton extends StatelessWidget {
  const _PrivacyBadgeButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cream,
          foregroundColor: AppColors.text,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () {},
        icon: const Icon(Icons.lock_outline, size: 18),
        label: const Text(
          'Public',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _HousemateActivityTile extends StatelessWidget {
  final HouseholdActivity activity;

  const _HousemateActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              activity.title,
              style: const TextStyle(
                fontSize: 17,
                color: AppColors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            activity.timestamp,
            style: const TextStyle(fontSize: 14, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _BarChartCard extends StatelessWidget {
  final List<double> values;
  final List<String> labels;

  const _BarChartCard({required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    final highestValue = values.isEmpty
        ? 0
        : values.reduce((a, b) => a > b ? a : b).ceil();

    final maxY = highestValue < 3 ? 3 : highestValue;

    final topLabel = maxY;
    final middleTopLabel = (maxY * 2 / 3).round();
    final middleBottomLabel = (maxY / 3).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 240,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 26,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -9),
                        child: Text(
                          '$topLabel',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -4),
                        child: Text(
                          '$middleTopLabel',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, 3),
                        child: Text(
                          '$middleBottomLabel',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, 2),
                        child: const Text(
                          '0',
                          style: TextStyle(fontSize: 14, color: AppColors.text),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildGridLine(),
                          _buildGridLine(),
                          _buildGridLine(),
                          _buildAxisLine(),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(values.length, (index) {
                            final heightFactor = (values[index] / maxY).clamp(
                              0.0,
                              1.0,
                            );

                            return Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: FractionallySizedBox(
                                        heightFactor: heightFactor,
                                        child: Container(
                                          width: 42,
                                          decoration: const BoxDecoration(
                                            color: AppColors.blue,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Row(
              children: List.generate(labels.length, (index) {
                return Expanded(
                  child: Center(
                    child: Text(
                      labels[index],
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridLine() {
    return Container(height: 2, color: const Color(0xFFA9A9A9));
  }

  Widget _buildAxisLine() {
    return Container(height: 2, color: AppColors.tan);
  }
}

class _HousemateStatsGrid extends StatelessWidget {
  final int choresDone;
  final int totalChores;
  final int uniqueChores;
  final int maxChoresInAWeek;
  final int choreStreak;

  const _HousemateStatsGrid({
    required this.choresDone,
    required this.totalChores,
    required this.uniqueChores,
    required this.maxChoresInAWeek,
    required this.choreStreak,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatItem(value: '$choresDone', label: 'Chores Done'),
      _StatItem(value: '$totalChores', label: 'Total Chores'),
      _StatItem(value: '$uniqueChores', label: 'Unique Chores'),
      _StatItem(value: '$maxChoresInAWeek', label: 'Max Chores\nin a Week'),
      _StatItem(
        value: '$choreStreak',
        valueSuffix: '\nweeks',
        label: 'Chore Streak',
      ),
      const _StatItem(value: '', label: '', isPlaceholder: true),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final stat = stats[index];

        return Container(
          decoration: BoxDecoration(
            color: stat.isPlaceholder
                ? const Color(0xFFD9D9D9)
                : AppColors.cream,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: stat.isPlaceholder
              ? const SizedBox.expand()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: stat.value,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          if (stat.valueSuffix != null)
                            TextSpan(
                              text: ' ${stat.valueSuffix}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.text,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stat.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _HouseholdActivities {
  final List<HouseholdActivity> overdue;
  final List<HouseholdActivity> todo;
  final List<HouseholdActivity> completed;

  const _HouseholdActivities({
    required this.overdue,
    required this.todo,
    required this.completed,
  });
}

class _HousemateData {
  final List<double> weeklyValues;
  final List<String> weekLabels;

  const _HousemateData({required this.weeklyValues, required this.weekLabels});
}

class _StatItem {
  final String value;
  final String label;
  final String? valueSuffix;
  final bool isPlaceholder;

  const _StatItem({
    required this.value,
    required this.label,
    this.valueSuffix,
    this.isPlaceholder = false,
  });
}

class ProfileAvatar extends StatelessWidget {
  final String photoUrl;
  final double size;
  final double borderWidth;

  const ProfileAvatar({
    super.key,
    required this.photoUrl,
    this.size = 100,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = photoUrl.isEmpty
        ? _defaultIcon()
        : CachedNetworkImage(
            imageUrl: photoUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            errorWidget: (_, _, _) => _defaultIcon(),
          );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: borderWidth > 0
            ? Border.all(color: AppColors.tan, width: borderWidth)
            : null,
        color: Colors.grey.shade300,
      ),
      child: ClipRRect(child: avatar),
    );
  }

  Widget _defaultIcon() {
    return Center(
      child: Icon(
        Icons.person_outline,
        size: size * 0.45,
        color: AppColors.tan,
      ),
    );
  }
}

class Housemate {
  final String uid;
  final String firstName;
  final String lastName;
  final String username;
  final String photoUrl;
  final String role;

  const Housemate({
    required this.uid,
    required this.firstName,
    this.lastName = '',
    this.username = '',
    this.photoUrl = '',
    this.role = 'member',
  });

  String get roleLabel {
    switch (role) {
      case 'parent':
        return 'Parent';
      case 'child':
        return 'Child';
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Admin';
      default:
        return 'Member';
    }
  }

  String get fullName => '$firstName $lastName'.trim();
}

class HouseholdActivity {
  final String title;
  final String timestamp;
  final String details;
  final String createdAt;
  final String completedBy;

  const HouseholdActivity({
    required this.title,
    required this.timestamp,
    required this.details,
    required this.completedBy,
    this.createdAt = '',
  });
}

class _WebFriendlyScrollBehavior extends MaterialScrollBehavior {
  const _WebFriendlyScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };
}
