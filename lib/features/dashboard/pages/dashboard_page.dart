import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_logo.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = true;

  String _displayName = 'Person Name';
  String _householdName = 'Household';
  String _startOfWeek = 'sunday';

  int _householdCompletedPercent = 0;

  List<DashboardLegendItem> _personalItems = [];
  List<DashboardLegendItem> _householdItems = [];

  final List<Color> _memberColors = const [
    Color(0xFF8B63D2),
    Color(0xFF4A2DE2),
    Color(0xFF4965E0),
    Color(0xFFAE4CC7),
    Color(0xFFD9AB63),
    Color(0xFF6FB2D9),
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data();
    if (userData == null) return;

    final householdId = userData['householdId'] ?? '';
    final firstName = userData['firstName'] ?? '';
    final lastName = userData['lastName'] ?? '';
    final startOfWeek = userData['startOfWeek'] ?? 'sunday';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = _startOfWeekFor(today, startOfWeek);
    final weekEnd = weekStart.add(const Duration(days: 7));

    String householdName = 'Household';

    if (householdId.toString().isNotEmpty) {
      final householdDoc = await FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .get();

      householdName = householdDoc.data()?['name'] ?? 'Household';
    }

    final choresSnapshot = await FirebaseFirestore.instance
        .collection('chores')
        .where('householdId', isEqualTo: householdId)
        .get();

    final chores = choresSnapshot.docs.map((doc) => doc.data()).toList();

    final personalChores = chores.where((chore) {
      return chore['assignedTo'] == user.uid;
    }).toList();

    final completed = personalChores.where((chore) {
      return chore['completed'] == true;
    }).length;

    final overdueTodo = personalChores.where((chore) {
      final dueDate = _readDate(chore['dueDate']);
      if (dueDate == null) return false;

      final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);

      return chore['completed'] != true && dueDateOnly.isBefore(weekStart);
    }).length;

    final todoThisWeek = personalChores.where((chore) {
      final dueDate = _readDate(chore['dueDate']);
      if (dueDate == null) return false;

      final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);

      return chore['completed'] != true &&
          !dueDateOnly.isBefore(weekStart) &&
          dueDateOnly.isBefore(weekEnd);
    }).length;

    final futureTodo = personalChores.where((chore) {
      final dueDate = _readDate(chore['dueDate']);
      if (dueDate == null) return false;

      final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);

      return chore['completed'] != true && !dueDateOnly.isBefore(weekEnd);
    }).length;

    final personalItems = [
      DashboardLegendItem(
        label: 'Completed',
        value: completed.toDouble(),
        displayPercent: _percent(completed, personalChores.length),
        color: const Color(0xFF8B63D2),
      ),
      DashboardLegendItem(
        label: 'Overdue To-do',
        value: overdueTodo.toDouble(),
        displayPercent: _percent(overdueTodo, personalChores.length),
        color: const Color(0xFFBFBFBF),
      ),
      DashboardLegendItem(
        label: 'To-do This Week',
        value: todoThisWeek.toDouble(),
        displayPercent: _percent(todoThisWeek, personalChores.length),
        color: const Color(0xFFD9AB63),
      ),
      DashboardLegendItem(
        label: 'Future To-do',
        value: futureTodo.toDouble(),
        displayPercent: _percent(futureTodo, personalChores.length),
        color: const Color(0xFF6FB2D9),
      ),
    ].where((item) => item.value > 0).toList();

    final weeklyChores = chores.where((chore) {
      final dueDate = _readDate(chore['dueDate']);
      if (dueDate == null) return false;

      final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);

      return !dueDateOnly.isBefore(weekStart) && dueDateOnly.isBefore(weekEnd);
    }).toList();

    final completedThisWeek = weeklyChores.where((chore) {
      return chore['completed'] == true;
    }).length;

    final todoCountsByMember = <String, int>{};

    for (final chore in weeklyChores) {
      if (chore['completed'] == true) continue;

      final name = chore['assignedToName'] ?? 'Unassigned';
      todoCountsByMember[name] = (todoCountsByMember[name] ?? 0) + 1;
    }

    final memberNames = todoCountsByMember.keys.toList();
    final householdItems = <DashboardLegendItem>[];

    if (completedThisWeek > 0) {
      householdItems.add(
        DashboardLegendItem(
          label: 'Completed',
          value: completedThisWeek.toDouble(),
          displayPercent: _percent(completedThisWeek, weeklyChores.length),
          color: const Color(0xFF8B63D2),
        ),
      );
    }

    for (final name in memberNames) {
      final index = memberNames.indexOf(name);
      final count = todoCountsByMember[name] ?? 0;

      householdItems.add(
        DashboardLegendItem(
          label: '$name To-do',
          value: count.toDouble(),
          displayPercent: _percent(count, weeklyChores.length),
          color: _memberColors[(index + 1) % _memberColors.length],
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _displayName = '$firstName $lastName'.trim().isNotEmpty
          ? '$firstName $lastName'.trim()
          : 'Person Name';
      _householdName = householdName;
      _startOfWeek = startOfWeek;
      _personalItems = personalItems;
      _householdItems = householdItems;
      _householdCompletedPercent = _percent(
        completedThisWeek,
        weeklyChores.length,
      );
      _isLoading = false;
    });
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

  int _percent(int value, int total) {
    if (total == 0) return 0;
    return ((value / total) * 100).round();
  }

  int _personalCompletionPercent() {
    final total = _personalItems.fold<double>(0, (total, item) {
      return total + item.value;
    });

    if (total == 0) return 0;

    final completed = _personalItems
        .where((item) => item.label == 'Completed')
        .fold<double>(0, (total, item) {
          return total + item.value;
        });

    return ((completed / total) * 100).round();
  }

  String _weekLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = _startOfWeekFor(today, _startOfWeek);

    return 'Week of ${_monthName(weekStart.month)} ${weekStart.day}, ${weekStart.year}';
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final weekLabel = _weekLabel();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: _DashboardHeader(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DashboardSummaryCard(
                      title: _displayName,
                      weekLabel: weekLabel,
                      centerPercent: _personalCompletionPercent(),
                      items: _personalItems,
                      rightColumnTitle: 'Status',
                    ),
                    const SizedBox(height: 22),
                    DashboardSummaryCard(
                      title: _householdName,
                      weekLabel: weekLabel,
                      centerPercent: _householdCompletedPercent,
                      items: _householdItems,
                      rightColumnTitle: 'Mate',
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

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppLogo(type: LogoType.wordmark, width: 230),
          ),
        ),
        Icon(Icons.notifications_none_rounded, size: 38, color: AppColors.blue),
      ],
    );
  }
}

class DashboardSummaryCard extends StatelessWidget {
  final String title;
  final String weekLabel;
  final int centerPercent;
  final List<DashboardLegendItem> items;
  final String rightColumnTitle;

  const DashboardSummaryCard({
    super.key,
    required this.title,
    required this.weekLabel,
    required this.centerPercent,
    required this.items,
    required this.rightColumnTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(28),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 560;

          final chart = SizedBox(
            width: isNarrow ? double.infinity : 230,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  weekLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.25,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 170,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 0,
                          centerSpaceRadius: 48,
                          startDegreeOffset: 140,
                          sections: items.isEmpty
                              ? [
                                  PieChartSectionData(
                                    value: 1,
                                    color: const Color(0xFFBFBFBF),
                                    radius: 28,
                                    showTitle: false,
                                  ),
                                ]
                              : items.map((item) {
                                  return PieChartSectionData(
                                    value: item.value,
                                    color: item.color,
                                    radius: 28,
                                    showTitle: false,
                                  );
                                }).toList(),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Total Value',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$centerPercent%',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          final legend = _LegendTable(
            items: items,
            middleHeader: rightColumnTitle,
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [chart, const SizedBox(height: 20), legend],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              chart,
              const SizedBox(width: 24),
              Expanded(child: legend),
            ],
          );
        },
      ),
    );
  }
}

class _LegendTable extends StatelessWidget {
  final List<DashboardLegendItem> items;
  final String middleHeader;

  const _LegendTable({required this.items, required this.middleHeader});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'No chores found for this week.',
        style: TextStyle(fontSize: 16, color: AppColors.text),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 2),
        Row(
          children: [
            const SizedBox(
              width: 28,
              child: Text(
                'Key',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                middleHeader,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(
              width: 56,
              child: Text(
                '%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Divider(height: 1, thickness: 1, color: Color(0xFFCEC7BC)),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, color: AppColors.text),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    '${item.displayPercent}%',
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 16, color: AppColors.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DashboardLegendItem {
  final String label;
  final double value;
  final int displayPercent;
  final Color color;

  const DashboardLegendItem({
    required this.label,
    required this.value,
    required this.displayPercent,
    required this.color,
  });
}
