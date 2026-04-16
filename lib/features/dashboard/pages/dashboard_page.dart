import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_logo.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    const personalWeekLabel = 'Week of April 15, 2026';
    const householdWeekLabel = 'Week of April 15, 2026';

    final personalItems = <DashboardLegendItem>[
      const DashboardLegendItem(
        label: 'Laundry',
        value: 1,
        displayPercent: 100,
        color: Color(0xFF8B63D2),
      ),
      const DashboardLegendItem(
        label: 'Dishwashing',
        value: 1,
        displayPercent: 100,
        color: Color(0xFFD9AB63),
      ),
      const DashboardLegendItem(
        label: 'Trash',
        value: 1,
        displayPercent: 100,
        color: Color(0xFF6FB2D9),
      ),
      const DashboardLegendItem(
        label: 'Vacuuming',
        value: 1,
        displayPercent: 100,
        color: Color(0xFF5E82F2),
      ),
      const DashboardLegendItem(
        label: 'Dusting',
        value: 1,
        displayPercent: 100,
        color: Color(0xFFD3C45D),
      ),
      const DashboardLegendItem(
        label: 'Tidying',
        value: 1,
        displayPercent: 0,
        color: Color(0xFFB45AC1),
      ),
    ];

    final householdItems = <DashboardLegendItem>[
      const DashboardLegendItem(
        label: 'Hillary',
        value: 1,
        displayPercent: 100,
        color: Color(0xFF8B63D2),
      ),
      const DashboardLegendItem(
        label: 'Garrett',
        value: 1,
        displayPercent: 100,
        color: Color(0xFF4A2DE2),
      ),
      const DashboardLegendItem(
        label: 'Geoffrey',
        value: 1,
        displayPercent: 100,
        color: Color(0xFF4965E0),
      ),
      const DashboardLegendItem(
        label: 'Nick',
        value: 1,
        displayPercent: 83,
        color: Color(0xFFAE4CC7),
      ),
      const DashboardLegendItem(
        label: 'Remaining',
        value: 0.2,
        displayPercent: 5,
        color: Color(0xFFBFBFBF),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DashboardHeader(),
              const SizedBox(height: 20),
              DashboardSummaryCard(
                title: 'Person Name',
                weekLabel: personalWeekLabel,
                centerPercent: 83,
                items: personalItems,
                rightColumnTitle: 'Chore',
              ),
              const SizedBox(height: 22),
              DashboardSummaryCard(
                title: 'Insert Awesome Group Name',
                weekLabel: householdWeekLabel,
                centerPercent: 95,
                items: householdItems,
                rightColumnTitle: 'Mate',
              ),
            ],
          ),
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
            child: AppLogo(type: LogoType.wordmark, width: 240),
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
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
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
                                sections: items
                                    .map(
                                      (item) => PieChartSectionData(
                                        value: item.value,
                                        color: item.color,
                                        radius: 28,
                                        showTitle: false,
                                      ),
                                    )
                                    .toList(),
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
                ),
              ),
              SizedBox(
                width: 210,
                child: _LegendTable(
                  items: items,
                  middleHeader: rightColumnTitle,
                ),
              ),
            ],
          ),
        ],
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
              width: 34,
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
                    style: const TextStyle(fontSize: 16, color: AppColors.text),
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${item.displayPercent}%',
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
