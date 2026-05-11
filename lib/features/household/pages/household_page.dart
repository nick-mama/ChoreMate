import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_logo.dart';

class HouseholdPage extends StatefulWidget {
  const HouseholdPage({super.key});

  @override
  State<HouseholdPage> createState() => _HouseholdPageState();
}

class _HouseholdPageState extends State<HouseholdPage> {
  final ScrollController _housematesScrollController = ScrollController();

  String _householdName = '';
  bool _loading = true;
  bool overdueExpanded = true;
  bool todoExpanded = true;
  bool completedExpanded = true;

  List<Housemate> housemates = [
    const Housemate(firstName: 'Hillary'),
    const Housemate(firstName: 'Garrett'),
    const Housemate(firstName: 'Geoffrey'),
    const Housemate(firstName: 'Nick'),
  ];

  final List<HouseholdActivity> overdueActivities = [
    const HouseholdActivity(
      title: 'Kitchen Counters',
      timestamp: '3/18/2026',
      details: 'Assigned to Hillary',
      completedBy: 'Hillary',
    ),
    const HouseholdActivity(
      title: 'Take Out Trash',
      timestamp: '3/19/2026',
      details: 'Assigned to Geoffrey',
      completedBy: 'Geoffrey',
    ),
  ];

  final List<HouseholdActivity> todoActivities = [
    const HouseholdActivity(
      title: 'Vacuum Living Room',
      timestamp: '3/24/2026',
      details: 'Assigned to Nick',
      completedBy: 'Nick',
    ),
    const HouseholdActivity(
      title: 'Clean Bathroom',
      timestamp: '3/25/2026',
      details: 'Assigned to Garrett',
      completedBy: 'Garrett',
    ),
  ];

  final List<HouseholdActivity> activities = [
    const HouseholdActivity(
      title: 'Laundry',
      timestamp: '3/20/2026, 3:22pm',
      details: 'Completed by Hillary',
      completedBy: 'Hillary',
    ),
    const HouseholdActivity(
      title: 'Dishwashing',
      timestamp: '3/19/2026, 1:18pm',
      details: 'Completed by Garrett',
      completedBy: 'Garrett',
    ),
    const HouseholdActivity(
      title: 'Trash',
      timestamp: '3/19/2026, 11:01am',
      details: 'Completed by Geoffrey',
      completedBy: 'Geoffrey',
    ),
    const HouseholdActivity(
      title: 'Vacuuming',
      timestamp: '3/18/2026, 7:22pm',
      details: 'Completed by Nick',
      completedBy: 'Nick',
    ),
    const HouseholdActivity(
      title: 'Dusting',
      timestamp: '3/16/2026, 5:13pm',
      details: 'Completed by Hillary',
      completedBy: 'Hillary',
    ),
    const HouseholdActivity(
      title: 'Tidying',
      timestamp: '3/16/2026, 5:13pm',
      details: 'Completed by Geoffrey',
      completedBy: 'Geoffrey',
    ),
  ];

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

    final householdId = userDoc.data()?['householdId'] ?? '';
    if (householdId.isEmpty) return;

    final householdDoc = await FirebaseFirestore.instance
        .collection('households')
        .doc(householdId)
        .get(const GetOptions(source: Source.server));

    final householdData = householdDoc.data();
    if (householdData == null) return;

    final householdName = (householdData['name'] as String?) ?? '';

    final rawMembers = householdData['members'];
    final memberUids = rawMembers is List
        ? rawMembers.whereType<String>().toList()
        : <String>[];
    final List<Housemate> loaded = [];

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

      loaded.add(
        Housemate(
          firstName: firstName.isNotEmpty ? firstName : uid,
          lastName: lastName,
          username: username,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _householdName = householdName;
      if (loaded.isNotEmpty) housemates = loaded;
      _loading = false;
    });
  }

  void _showActivityOverlay(HouseholdActivity activity) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActivityOverlay(activity: activity),
    );
  }

  void _openHousemateProfile(Housemate housemate) {
    final housemateActivities = activities
        .where((a) => a.completedBy == housemate.firstName)
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HousemateProfilePage(
          housemate: housemate,
          activities: housemateActivities,
        ),
      ),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HouseholdHeader(),
              const SizedBox(height: 28),
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
                  style: const TextStyle(fontSize: 16, color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  border: Border.all(color: const Color(0xFF7C7468), width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 4,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ScrollConfiguration(
                      behavior: const _WebFriendlyScrollBehavior(),
                      child: SizedBox(
                        height: 170,
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
                    const SizedBox(height: 8),
                  ],
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
                  const _EmptyStateCard(text: 'No overdue chores.')
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
                  const _EmptyStateCard(text: 'No chores left. Nice work.')
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
                if (activities.isEmpty)
                  const _EmptyStateCard(text: 'No completed chores yet.')
                else
                  ...activities.map(
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
    );
  }
}

class _HouseholdHeader extends StatelessWidget {
  const _HouseholdHeader();

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
        Icon(Icons.notifications_none_rounded, size: 38, color: AppColors.text),
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
            ProfileAvatar(imagePath: housemate.imagePath, size: 106),
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

class _EmptyStateCard extends StatelessWidget {
  final String text;

  const _EmptyStateCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(12),
      ),
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
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class HousemateProfilePage extends StatelessWidget {
  final Housemate housemate;
  final List<HouseholdActivity> activities;
  final List<double> weeklyValues;
  final List<String> weekLabels;

  HousemateProfilePage({
    super.key,
    required this.housemate,
    required this.activities,
  }) : weeklyValues = [1, 3, 2, 4],
       weekLabels = ['Mar 2', 'Mar 9', 'Mar 16', 'Mar 23'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            28 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                ],
              ),
              const SizedBox(height: 28),
              _HousemateProfileSection(housemate: housemate),
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
              _HousemateBarChartCard(values: weeklyValues, labels: weekLabels),
              const SizedBox(height: 10),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDot(active: true),
                    const SizedBox(width: 6),
                    _buildDot(active: false),
                  ],
                ),
              ),
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
              if (activities.isEmpty)
                const Text(
                  'No chores recorded yet.',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                )
              else
                ...activities.map(
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
              _HousemateStatsGrid(choresDone: activities.length),
            ],
          ),
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
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.tan, width: 8),
              ),
              child: housemate.imagePath != null
                  ? Image.asset(housemate.imagePath!, fit: BoxFit.cover)
                  : const Center(
                      child: Icon(
                        Icons.person_outline,
                        size: 54,
                        color: AppColors.tan,
                      ),
                    ),
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
                label: 'Share',
                onTap: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _PrivacyBadgeButton()),
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

class _HousemateBarChartCard extends StatelessWidget {
  final List<double> values;
  final List<String> labels;

  const _HousemateBarChartCard({required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    const maxY = 6.0;

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
                    children: const [
                      SizedBox(),
                      Text(
                        '4',
                        style: TextStyle(fontSize: 14, color: AppColors.text),
                      ),
                      Text(
                        '2',
                        style: TextStyle(fontSize: 14, color: AppColors.text),
                      ),
                      Text(
                        '0',
                        style: TextStyle(fontSize: 14, color: AppColors.text),
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
                          const SizedBox(height: 1),
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

  const _HousemateStatsGrid({required this.choresDone});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatItem(value: '$choresDone', label: 'Chores Done'),
      const _StatItem(value: '20', label: 'Total Chores'),
      const _StatItem(value: '5', label: 'Unique Chores'),
      const _StatItem(value: '6.5', label: 'Hours of Chores'),
      const _StatItem(
        value: '2',
        valueSuffix: '\nweeks',
        label: 'Chore Streak',
      ),
      const _StatItem(value: '3', label: 'Roommates'),
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

class ProfileAvatar extends StatelessWidget {
  final String? imagePath;
  final double size;

  const ProfileAvatar({super.key, this.imagePath, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: imagePath != null
          ? Image.asset(
              imagePath!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _defaultIcon(),
            )
          : _defaultIcon(),
    );
  }

  Widget _defaultIcon() {
    return Icon(Icons.person, size: size * 0.4, color: Colors.grey.shade600);
  }
}

class Housemate {
  final String firstName;
  final String lastName;
  final String? imagePath;
  final String username;

  const Housemate({
    required this.firstName,
    this.lastName = '',
    this.imagePath,
    this.username = '',
  });

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
    this.createdAt = '3/15/2026, 9:00am',
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
