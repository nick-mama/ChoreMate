import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/app_logo.dart';
import 'account_settings_page.dart';
import '../../../shared/widgets/notification_bell.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final PageController _chartController = PageController();

  bool _loading = true;
  int _chartIndex = 0;

  String _displayName = '';
  String _username = '';
  String _householdName = '';
  String _photoUrl = '';
  String _role = 'member';

  int _housemates = 0;
  int _choresDone = 0;
  int _totalChores = 0;
  int _uniqueChores = 0;
  int _maxChoresInAWeek = 0;
  int _choreStreak = 0;

  List<double> individualValues = [0, 0, 0, 0];
  List<double> householdValues = [0, 0, 0, 0];
  List<String> weekLabels = ['', '', '', ''];

  String get _roleLabel {
    switch (_role) {
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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _chartController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));

    final data = doc.data();
    if (data == null) return;

    final firstName = data['firstName'] ?? '';
    final lastName = data['lastName'] ?? '';
    final username = data['username'] ?? '';
    final householdId = data['householdId'] ?? '';
    final startOfWeek = data['startOfWeek'] ?? 'sunday';
    final photoUrl = data['photoUrl'] ?? '';

    String householdName = '';
    String role = 'member';

    if (householdId.isNotEmpty) {
      final householdDoc = await FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .get(const GetOptions(source: Source.server));

      final householdData = householdDoc.data() ?? {};
      householdName = householdData['name'] ?? '';

      final roles = householdData['memberRoles'];
      if (roles is Map && roles[user.uid] is String) {
        role = roles[user.uid] as String;
      } else if (householdData['ownerId'] == user.uid ||
          householdData['createdBy'] == user.uid) {
        role = 'owner';
      }
    }

    final accountData = await _loadAccountData(
      user.uid,
      householdId,
      startOfWeek,
    );

    if (!mounted) return;
    setState(() {
      _displayName = '$firstName $lastName'.trim();
      _username = username;
      _householdName = householdName;
      _photoUrl = photoUrl;
      _role = role;

      individualValues = accountData.individualValues;
      householdValues = accountData.householdValues;
      weekLabels = accountData.weekLabels;

      _housemates = accountData.housemates;
      _choresDone = accountData.choresDone;
      _totalChores = accountData.totalChores;
      _uniqueChores = accountData.uniqueChores;
      _maxChoresInAWeek = accountData.maxChoresInAWeek;
      _choreStreak = accountData.choreStreak;

      _loading = false;
    });
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountSettingsPage()),
    );

    if (!mounted) return;
    setState(() => _loading = true);
    await _loadUserData();
  }

  Future<void> _shareChoreMate() async {
    final inviter = _displayName.isNotEmpty ? _displayName : 'Someone';
    final householdText = _householdName.isNotEmpty
        ? ' Join my household "$_householdName" and let’s keep chores organized together.'
        : ' Let’s keep chores organized together.';

    final message =
        '$inviter invited you to try ChoreMate!$householdText\n\n'
        'Download ChoreMate and make household chores easier.';

    try {
      await SharePlus.instance.share(
        ShareParams(text: message, subject: 'Join me on ChoreMate'),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open share options.')),
      );
    }
  }

  Future<_AccountData> _loadAccountData(
    String uid,
    String householdId,
    String startOfWeek,
  ) async {
    final chartData = _emptyChartData(startOfWeek);

    if (householdId.isEmpty) {
      return _AccountData.fromChartData(chartData);
    }

    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('householdId', isEqualTo: householdId)
        .get(const GetOptions(source: Source.server));

    final choresSnapshot = await FirebaseFirestore.instance
        .collection('chores')
        .where('householdId', isEqualTo: householdId)
        .get(const GetOptions(source: Source.server));

    final housemates = (usersSnapshot.docs.length - 1).clamp(0, 999999);
    final totalChores = choresSnapshot.docs.length;

    final uniqueNames = <String>{};
    final completedWeeks = <DateTime>{};

    var choresDone = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekStart = _startOfWeekFor(today, startOfWeek);
    final firstWeekStart = currentWeekStart.subtract(const Duration(days: 21));
    final lastWeekEnd = currentWeekStart.add(const Duration(days: 7));

    final individualCounts = List<double>.filled(4, 0);
    final householdCounts = List<double>.filled(4, 0);

    for (final doc in choresSnapshot.docs) {
      final data = doc.data();

      final name = (data['name'] ?? '').toString().trim().toLowerCase();
      if (name.isNotEmpty) {
        uniqueNames.add(name);
      }

      if (data['completed'] != true) continue;

      choresDone += 1;

      final completedAt = _readDate(data['completedAt']);
      if (completedAt == null) continue;

      final completedDate = DateTime(
        completedAt.year,
        completedAt.month,
        completedAt.day,
      );

      final streakWeekStart = _startOfWeekFor(completedDate, startOfWeek);

      completedWeeks.add(
        DateTime(
          streakWeekStart.year,
          streakWeekStart.month,
          streakWeekStart.day,
        ),
      );

      if (completedDate.isBefore(firstWeekStart) ||
          !completedDate.isBefore(lastWeekEnd)) {
        continue;
      }

      final weekIndex = completedDate.difference(firstWeekStart).inDays ~/ 7;
      if (weekIndex < 0 || weekIndex > 3) continue;

      householdCounts[weekIndex] += 1;

      if (data['assignedTo'] == uid) {
        individualCounts[weekIndex] += 1;
      }
    }

    final maxChoresInAWeek = individualCounts.isEmpty
        ? 0
        : individualCounts.reduce((a, b) => a > b ? a : b).toInt();

    return _AccountData(
      individualValues: individualCounts,
      householdValues: householdCounts,
      weekLabels: chartData.weekLabels,
      housemates: housemates,
      choresDone: choresDone,
      totalChores: totalChores,
      uniqueChores: uniqueNames.length,
      maxChoresInAWeek: maxChoresInAWeek,
      choreStreak: completedWeeks.length,
    );
  }

  _ChartData _emptyChartData(String startOfWeek) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekStart = _startOfWeekFor(today, startOfWeek);
    final firstWeekStart = currentWeekStart.subtract(const Duration(days: 21));

    final labels = List.generate(4, (index) {
      final weekStart = firstWeekStart.add(Duration(days: index * 7));
      return '${_shortMonthName(weekStart.month)} ${weekStart.day}';
    });

    return _ChartData(
      individualValues: List<double>.filled(4, 0),
      householdValues: List<double>.filled(4, 0),
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

  Future<void> _signOut() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRouter.login,
      (route) => false,
    );
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
              child: _AccountHeader(),
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
                    _ProfileSection(
                      displayName: _displayName,
                      username: _username,
                      role: _roleLabel,
                      householdName: _householdName,
                      photoUrl: _photoUrl,
                      onSettings: _openSettings,
                      onShare: _shareChoreMate,
                      onSignOut: _signOut,
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Chores Completed',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 340,
                      child: PageView(
                        controller: _chartController,
                        onPageChanged: (index) {
                          setState(() => _chartIndex = index);
                        },
                        children: [
                          _ChartPage(
                            title: 'Individual',
                            values: individualValues,
                            labels: weekLabels,
                          ),
                          _ChartPage(
                            title: 'Household',
                            values: householdValues,
                            labels: weekLabels,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDot(active: _chartIndex == 0),
                          const SizedBox(width: 6),
                          _buildDot(active: _chartIndex == 1),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Account Stats',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _StatsGrid(
                      housemates: _housemates,
                      choresDone: _choresDone,
                      totalChores: _totalChores,
                      uniqueChores: _uniqueChores,
                      maxChoresInAWeek: _maxChoresInAWeek,
                      choreStreak: _choreStreak,
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

  Widget _buildDot({required bool active}) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.muted : const Color(0xFFCFCFCF),
      ),
    );
  }
}

class _ChartData {
  final List<double> individualValues;
  final List<double> householdValues;
  final List<String> weekLabels;

  const _ChartData({
    required this.individualValues,
    required this.householdValues,
    required this.weekLabels,
  });
}

class _AccountData {
  final List<double> individualValues;
  final List<double> householdValues;
  final List<String> weekLabels;

  final int housemates;
  final int choresDone;
  final int totalChores;
  final int uniqueChores;
  final int maxChoresInAWeek;
  final int choreStreak;

  const _AccountData({
    required this.individualValues,
    required this.householdValues,
    required this.weekLabels,
    required this.housemates,
    required this.choresDone,
    required this.totalChores,
    required this.uniqueChores,
    required this.maxChoresInAWeek,
    required this.choreStreak,
  });

  factory _AccountData.fromChartData(_ChartData chartData) {
    return _AccountData(
      individualValues: chartData.individualValues,
      householdValues: chartData.householdValues,
      weekLabels: chartData.weekLabels,
      housemates: 0,
      choresDone: 0,
      totalChores: 0,
      uniqueChores: 0,
      maxChoresInAWeek: 0,
      choreStreak: 0,
    );
  }
}

class _ChartPage extends StatelessWidget {
  final String title;
  final List<double> values;
  final List<String> labels;

  const _ChartPage({
    required this.title,
    required this.values,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, color: AppColors.text),
        ),
        const SizedBox(height: 14),
        _BarChartCard(values: values, labels: labels),
      ],
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader();

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

class _ProfileSection extends StatelessWidget {
  final String displayName;
  final String username;
  final String role;
  final String householdName;
  final String photoUrl;
  final VoidCallback onSettings;
  final VoidCallback onShare;
  final VoidCallback onSignOut;

  const _ProfileSection({
    required this.displayName,
    required this.username,
    required this.role,
    required this.householdName,
    required this.photoUrl,
    required this.onSettings,
    required this.onShare,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final nameText = displayName.isNotEmpty ? displayName : 'Name';
    final usernameText = username.isNotEmpty ? '@$username' : 'Username';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileAvatarBox(photoUrl: photoUrl),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      nameText,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  Text(
                    usernameText,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    householdName.isNotEmpty ? '$role • $householdName' : role,
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
              child: _ActionButton(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: onSettings,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                icon: Icons.ios_share_outlined,
                label: 'Invite',
                onTap: onShare,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _LogOutButton(onTap: onSignOut)),
          ],
        ),
      ],
    );
  }
}

class _ProfileAvatarBox extends StatelessWidget {
  final String photoUrl;

  const _ProfileAvatarBox({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.tan, width: 8),
      ),
      child: ClipRRect(
        child: photoUrl.isEmpty
            ? const Center(
                child: Icon(
                  Icons.person_outline,
                  size: 54,
                  color: AppColors.tan,
                ),
              )
            : CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (_, _, _) => const Center(
                  child: Icon(
                    Icons.person_outline,
                    size: 54,
                    color: AppColors.tan,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
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

class _LogOutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogOutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cream,
          foregroundColor: AppColors.text,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onTap,
        child: const Text(
          'Log Out',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
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

class _StatsGrid extends StatelessWidget {
  final int housemates;
  final int choresDone;
  final int totalChores;
  final int uniqueChores;
  final int maxChoresInAWeek;
  final int choreStreak;

  const _StatsGrid({
    required this.housemates,
    required this.choresDone,
    required this.totalChores,
    required this.uniqueChores,
    required this.maxChoresInAWeek,
    required this.choreStreak,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatItem(value: '$housemates', label: 'Housemates'),
      _StatItem(value: '$choresDone', label: 'Chores Done'),
      _StatItem(value: '$totalChores', label: 'Total Chores'),
      _StatItem(value: '$uniqueChores', label: 'Unique Chores'),
      _StatItem(value: '$maxChoresInAWeek', label: 'Max Chores\nin a Week'),
      _StatItem(
        value: '$choreStreak',
        valueSuffix: '\nweeks',
        label: 'Chore Streak',
      ),
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
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
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
                style: const TextStyle(fontSize: 13, color: AppColors.text),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatItem {
  final String value;
  final String label;
  final String? valueSuffix;

  const _StatItem({required this.value, required this.label, this.valueSuffix});
}
