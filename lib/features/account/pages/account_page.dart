import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_logo.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final List<double> weeklyValues = [2, 4, 5, 3];
  final List<String> weekLabels = ['Mar 2', 'Mar 9', 'Mar 16', 'Mar 23'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _AccountHeader(),
              const SizedBox(height: 28),
              const _ProfileSection(),
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
              const SizedBox(height: 18),
              const Text(
                'Account Stats',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 14),
              const _StatsGrid(),
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

class _AccountHeader extends StatelessWidget {
  const _AccountHeader();

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

class _ProfileSection extends StatelessWidget {
  const _ProfileSection();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ProfileAvatarBox(),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Name',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Username',
                style: TextStyle(fontSize: 16, color: AppColors.text),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ActionButton(
                    icon: Icons.settings_outlined,
                    label: 'Edit Profile',
                    onTap: () {},
                  ),
                  _ActionButton(
                    icon: Icons.ios_share_outlined,
                    label: 'Share',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatarBox extends StatelessWidget {
  const _ProfileAvatarBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.tan, width: 8),
      ),
      child: const Center(
        child: Icon(Icons.person_outline, size: 54, color: AppColors.tan),
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
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.tan,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                                          decoration: BoxDecoration(
                                            color: AppColors.blue,
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(0),
                                                ),
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
  const _StatsGrid();

  @override
  Widget build(BuildContext context) {
    final stats = const [
      _StatItem(value: '3', label: 'Roommates'),
      _StatItem(value: '17', label: 'Chores Done'),
      _StatItem(value: '20', label: 'Total Chores'),
      _StatItem(value: '8', label: 'Unique Chores'),
      _StatItem(value: '10.5', label: 'Hours of Chores'),
      _StatItem(value: '4 weeks', label: 'Chore Streak'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
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
              Text(
                stat.value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
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

  const _StatItem({required this.value, required this.label});
}
