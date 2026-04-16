import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_logo.dart';

class HouseholdPage extends StatefulWidget {
  const HouseholdPage({super.key});

  @override
  State<HouseholdPage> createState() => _HouseholdPageState();
}

class _HouseholdPageState extends State<HouseholdPage> {
  final ScrollController _housematesScrollController = ScrollController();

  final List<Housemate> housemates = [
    const Housemate(name: 'Hillary'),
    const Housemate(name: 'Garrett'),
    const Housemate(name: 'Geoffrey'),
    const Housemate(name: 'Nick'),
  ];

  final List<HouseholdActivity> activities = [
    const HouseholdActivity(
      title: 'Laundry',
      timestamp: '3/20/2026, 3:22pm',
      details: 'Completed by Hillary',
    ),
    const HouseholdActivity(
      title: 'Dishwashing',
      timestamp: '3/19/2026, 1:18pm',
      details: 'Completed by Garrett',
    ),
    const HouseholdActivity(
      title: 'Trash',
      timestamp: '3/19/2026, 11:01am',
      details: 'Completed by Geoffrey',
    ),
    const HouseholdActivity(
      title: 'Vacuuming',
      timestamp: '3/18/2026, 7:22pm',
      details: 'Completed by Nick',
    ),
    const HouseholdActivity(
      title: 'Dusting',
      timestamp: '3/16/2026, 5:13pm',
      details: 'Completed by Hillary',
    ),
    const HouseholdActivity(
      title: 'Tidying',
      timestamp: '3/16/2026, 5:13pm',
      details: 'Completed by Geoffrey',
    ),
  ];

  @override
  void dispose() {
    _housematesScrollController.dispose();
    super.dispose();
  }

  void _showActivityOverlay(HouseholdActivity activity) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActivityOverlay(activity: activity),
    );
  }

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
                        height: 150,
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
                              );
                            },
                            separatorBuilder: (_, __) =>
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

              ...activities.map(
                (activity) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HouseholdActivityTile(
                    title: activity.title,
                    timestamp: activity.timestamp,
                    onTap: () => _showActivityOverlay(activity),
                  ),
                ),
              ),
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

class _HousemateCard extends StatelessWidget {
  final Housemate housemate;

  const _HousemateCard({required this.housemate});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 125,
      child: Column(
        children: [
          ProfileAvatar(imagePath: housemate.imagePath, size: 106),
          const SizedBox(height: 10),
          Text(
            housemate.name,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HouseholdActivityTile extends StatelessWidget {
  final String title;
  final String timestamp;
  final VoidCallback onTap;

  const _HouseholdActivityTile({
    required this.title,
    required this.timestamp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.field,
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
                  style: const TextStyle(
                    fontSize: 17,
                    color: AppColors.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                timestamp,
                style: const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
            ],
          ),
        ),
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
      margin: const EdgeInsets.all(16),
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
            _OverlayField('Completed:', activity.timestamp),
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
              errorBuilder: (_, __, ___) => _defaultIcon(),
            )
          : _defaultIcon(),
    );
  }

  Widget _defaultIcon() {
    return Icon(Icons.person, size: size * 0.4, color: Colors.grey.shade600);
  }
}

class Housemate {
  final String name;
  final String? imagePath;

  const Housemate({required this.name, this.imagePath});
}

class HouseholdActivity {
  final String title;
  final String timestamp;
  final String details;
  final String createdAt;

  const HouseholdActivity({
    required this.title,
    required this.timestamp,
    required this.details,
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
