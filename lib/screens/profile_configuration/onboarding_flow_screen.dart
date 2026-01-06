// lib/screens/onboarding/onboarding_flow_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:peak_flow/features/onboarding/providers/onboarding_notifier_provider.dart';
import 'package:peak_flow/features/onboarding/providers/profile_controller_provider.dart';

/// Main onboarding flow widget
///
/// - 4 screens in a PageView
/// - writes inputs into `onboardingDraftProvider`
/// - final submit uses `profileSetupControllerProvider.completeProfile()`
/// - router/auth reacts automatically via Firestore + auth state
/// Main onboarding flow widget
/// Main onboarding flow widget
class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  // Local UI inputs for the rhythm page
  String? _selectedChronotype; // "Morning" | "Midday" | "Evening"
  TimeOfDay? _wakeTime;
  TimeOfDay? _bedTime;

  // --- helpers --------------------------------------------------------------

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    setState(() {
      _pageIndex = index;
    });
  }

  void _nextPage() {
    if (_pageIndex < 3) _goToPage(_pageIndex + 1);
  }

  void _prevPage() {
    if (_pageIndex > 0) _goToPage(_pageIndex - 1);
  }

  Future<void> _pickTime({
    required bool isWake,
    required TimeOfDay initialTime,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: isWake ? 'Select Wake Time' : 'Select Bed Time',
    );

    if (picked != null) {
      setState(() {
        if (isWake) {
          _wakeTime = picked;
        } else {
          _bedTime = picked;
        }
      });
    }
  }

  int _hour0to23Round(TimeOfDay t) {
    return (t.hour + (t.minute >= 30 ? 1 : 0)) % 24;
  }

  bool _validateWakeBed() {
    if (_wakeTime == null || _bedTime == null) {
      _showSnack('Please select wake and bed times');
      return false;
    }

    final wakeMinutes = _wakeTime!.hour * 60 + _wakeTime!.minute;
    final bedMinutes = _bedTime!.hour * 60 + _bedTime!.minute;

    if (wakeMinutes >= bedMinutes) {
      _showSnack('Bedtime must be after wake time');
      return false;
    }

    return true;
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Called from Page 1 "Continue" (index 1 -> index 2)
  void _handleContinueRhythm() {
    if (_selectedChronotype != null) {
      ref
          .read(onboardingDraftProvider.notifier)
          .updateChronotype(_selectedChronotype!);
    }

    if (!_validateWakeBed()) return;

    ref
        .read(onboardingDraftProvider.notifier)
        .updateSleepTimes(
          _wakeTime!.format(context),
          _bedTime!.format(context),
          _hour0to23Round(_wakeTime!),
          _hour0to23Round(_bedTime!),
        );

    _nextPage();
  }

  Future<void> _handleFinish() async {
    if (!_validateWakeBed()) {
      _goToPage(1);
      return;
    }

    try {
      await ref.read(profileSetupControllerProvider.notifier).completeProfile();
      context.go('/');
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  void _startFromIntro() => _nextPage();

  Future<void> _openLearnMore() async {
    final url = Uri.parse('https://setupapp.io');
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) _showSnack("Couldn't open website");
  }

  @override
  Widget build(BuildContext context) {
    // Keep UI intact, but wire submission/loading to controller provider
    final submitState = ref.watch(profileSetupControllerProvider);
    final finishing = submitState.isLoading;

    ref.listen<AsyncValue<void>>(profileSetupControllerProvider, (_, next) {
      next.whenOrNull(error: (err, __) => _showSnack(err.toString()));
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      body: SafeArea(
        // Wrapping with SafeArea to avoid overlap with system UI
        child: Stack(
          children: [
            // PageView with screens
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) {
                setState(() => _pageIndex = i);
              },
              children: [
                _PageIntro(
                  onNext: _startFromIntro,
                  currentIndex: 0,
                  onLearnMore: _openLearnMore,
                ),
                _PageRhythmSetup(
                  selectedChronotype: _selectedChronotype,
                  onSelectChronotype: (val) {
                    setState(() => _selectedChronotype = val);
                    ref
                        .read(onboardingDraftProvider.notifier)
                        .updateChronotype(val);
                  },
                  wakeTime: _wakeTime,
                  bedTime: _bedTime,
                  onPickWake: () => _pickTime(
                    isWake: true,
                    initialTime:
                        _wakeTime ?? const TimeOfDay(hour: 7, minute: 0),
                  ),
                  onPickBed: () => _pickTime(
                    isWake: false,
                    initialTime:
                        _bedTime ?? const TimeOfDay(hour: 23, minute: 0),
                  ),
                  onContinue: _handleContinueRhythm,
                  currentIndex: 1,
                  onLearnMore: _openLearnMore,
                ),
                _PageTiming(
                  onNext: _nextPage,
                  currentIndex: 2,
                  onLearnMore: _openLearnMore,
                ),
                _PageFeedback(
                  onFinish: _handleFinish,
                  finishing: finishing,
                  currentIndex: 3,
                  onLearnMore: _openLearnMore,
                ),
              ],
            ),
            // Custom back button at the top, conditionally visible
            if (_pageIndex >
                0) // Only show back button on pages after the first one
              Positioned(
                top: 10,
                left: 16,
                child: IconButton(
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Color(0xFF1F1F2D),
                  ),
                  onPressed: _prevPage,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shared responsive layout wrapper
class OnboardingPageShell extends StatelessWidget {
  const OnboardingPageShell({
    super.key,
    required this.topSection,
    required this.bottomSection,
  });

  final Widget topSection;
  final Widget bottomSection;

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF8F5FF);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Container(
                color: bg.withOpacity(0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [topSection, const Spacer(), bottomSection],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// PAGE 0 ----------------------------------------------------------------------
class _PageIntro extends StatelessWidget {
  final VoidCallback onNext;
  final int currentIndex;
  final VoidCallback onLearnMore;

  const _PageIntro({
    required this.onNext,
    required this.currentIndex,
    required this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingPageShell(
      topSection: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          const SizedBox(width: 120, height: 120, child: _BrainBoltLogo()),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Work with your rhythm,\nnot against it.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.3,
                letterSpacing: 0.3,
                color: const Color(0xFF1F1F2D),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Good days and bad days often feel random and unpredictable. "
              "Watt can help you stop guessing and start understanding your "
              "body's natural energy patterns, so you can perform at your best, "
              "consistently.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                letterSpacing: 0.3,
                color: const Color(0xFF51516F),
              ),
            ),
          ),
        ],
      ),
      bottomSection: _PageFooter(
        buttonLabel: 'Get Started',
        onButtonTap: onNext,
        currentIndex: currentIndex,
        total: 4,
        onLearnMore: onLearnMore,
      ),
    );
  }
}

// PAGE 1 ----------------------------------------------------------------------

class _PageRhythmSetup extends StatelessWidget {
  final String? selectedChronotype;
  final ValueChanged<String> onSelectChronotype;

  final TimeOfDay? wakeTime;
  final TimeOfDay? bedTime;
  final VoidCallback onPickWake;
  final VoidCallback onPickBed;

  final VoidCallback onContinue;
  final int currentIndex;
  final VoidCallback onLearnMore;

  const _PageRhythmSetup({
    required this.selectedChronotype,
    required this.onSelectChronotype,
    required this.wakeTime,
    required this.bedTime,
    required this.onPickWake,
    required this.onPickBed,
    required this.onContinue,
    required this.currentIndex,
    required this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingPageShell(
      topSection: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Let's Start Fast by Setting your Rhythm",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: const Color(0xFF1F1F2D),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose your rhythm and wake hours.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: const Color(0xFF51516F),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'When do you feel most awake and productive?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F1F2D),
            ),
          ),
          const SizedBox(height: 16),
          _ChronotypeRow(
            selected: selectedChronotype,
            onSelect: onSelectChronotype,
          ),
          const SizedBox(height: 24),
          _TimeCard(
            icon: Icons.wb_sunny_outlined,
            label: 'When do you typically wake up?',
            valueText: wakeTime == null
                ? 'Select Time'
                : wakeTime!.format(context),
            onTap: onPickWake,
          ),
          const SizedBox(height: 16),
          _TimeCard(
            icon: Icons.bedtime_outlined,
            label: 'When do you typically go to bed?',
            valueText: bedTime == null
                ? 'Select Time'
                : bedTime!.format(context),
            onTap: onPickBed,
          ),
        ],
      ),
      bottomSection: _PageFooter(
        buttonLabel: 'Continue',
        onButtonTap: onContinue,
        currentIndex: currentIndex,
        total: 4,
        onLearnMore: onLearnMore,
      ),
    );
  }
}

// PAGE 2 ----------------------------------------------------------------------

class _PageTiming extends StatelessWidget {
  final VoidCallback onNext;
  final int currentIndex;
  final VoidCallback onLearnMore;

  const _PageTiming({
    required this.onNext,
    required this.currentIndex,
    required this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingPageShell(
      topSection: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 62),
          const _TimingPreviewArt(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "It's all about timing",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: const Color(0xFF1F1F2D),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Calendars ignore how your energy really moves. Watt gives each "
              "hour an Energy Score (1–100) and tells you when to push, cruise, "
              "or recharge — so you can perform at your best",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: const Color(0xFF51516F),
              ),
            ),
          ),
        ],
      ),
      bottomSection: _PageFooter(
        buttonLabel: 'Continue',
        onButtonTap: onNext,
        currentIndex: currentIndex,
        total: 4,
        onLearnMore: onLearnMore,
      ),
    );
  }
}

// PAGE 3 ----------------------------------------------------------------------

class _PageFeedback extends StatelessWidget {
  final VoidCallback onFinish;
  final bool finishing;
  final int currentIndex;
  final VoidCallback onLearnMore;

  const _PageFeedback({
    required this.onFinish,
    required this.finishing,
    required this.currentIndex,
    required this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingPageShell(
      topSection: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          const _FeedbackPreviewArt(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Watt lives of your feedback',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: const Color(0xFF1F1F2D),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Just rate how accurate our prediction was — the more feedback "
              "you give, the smarter Watt gets. Soon it’ll know your energy "
              "and mood better than you do. You can also rate your sleep or "
              "log boosts like coffee, naps, or workouts.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: const Color(0xFF51516F),
              ),
            ),
          ),
        ],
      ),
      bottomSection: _PageFooter(
        buttonLabel: 'Start Using Watt',
        onButtonTap: finishing ? null : onFinish,
        currentIndex: currentIndex,
        total: 4,
        onLearnMore: onLearnMore,
        isLoading: finishing,
      ),
    );
  }
}

// FOOTER ----------------------------------------------------------------------

class _PageFooter extends StatelessWidget {
  final String buttonLabel;
  final VoidCallback? onButtonTap;
  final int currentIndex;
  final int total;
  final VoidCallback onLearnMore;
  final bool isLoading;

  const _PageFooter({
    required this.buttonLabel,
    required this.onButtonTap,
    required this.currentIndex,
    required this.total,
    required this.onLearnMore,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: onButtonTap,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF4A4B7E),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      buttonLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _PageDots(currentIndex: currentIndex, total: total),
        const SizedBox(height: 16),
        _LearnMoreLink(onTap: onLearnMore),
        const SizedBox(height: 8),
      ],
    );
  }
}

// PAGE DOTS -------------------------------------------------------------------

class _PageDots extends StatelessWidget {
  final int currentIndex;
  final int total;

  const _PageDots({required this.currentIndex, required this.total});

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF4A4B7E);
    const inactiveColor = Color(0xFFC5C5D6);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == currentIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 32 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

// LEARN MORE LINK -------------------------------------------------------------

class _LearnMoreLink extends StatelessWidget {
  final VoidCallback onTap;

  const _LearnMoreLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF51516F);
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text(
            'Learn more about how Watt works',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(width: 6),
          Icon(Icons.open_in_new_rounded, size: 16, color: color),
        ],
      ),
    );
  }
}

// RHYTHM CHOOSER ROW ----------------------------------------------------------

class _ChronotypeRow extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _ChronotypeRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _ChronotypeCard(
            label: 'Morning',
            icon: Icons.wb_sunny,
            isSelected: selected == 'Morning',
            onTap: () => onSelect('Morning'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ChronotypeCard(
            label: 'Midday',
            icon: Icons.timelapse,
            isSelected: selected == 'Midday',
            onTap: () => onSelect('Midday'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ChronotypeCard(
            label: 'Evening',
            icon: Icons.nightlight_round,
            isSelected: selected == 'Evening',
            onTap: () => onSelect('Evening'),
          ),
        ),
      ],
    );
  }
}

class _ChronotypeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChronotypeCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF4A4B7E);
    final cardBg = isSelected ? activeColor.withOpacity(0.08) : Colors.white;
    final borderColor = isSelected ? activeColor : Colors.grey.shade300;
    final textColor = isSelected ? const Color(0xFF1F1F2D) : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              spreadRadius: 0,
              offset: Offset(0, 4),
              color: Colors.black12,
            ),
          ],
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFFD83D), size: 40),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

// TIME CARD -------------------------------------------------------------------

class _TimeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valueText;
  final VoidCallback onTap;

  const _TimeCard({
    required this.icon,
    required this.label,
    required this.valueText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.grey.shade300;
    const iconColor = Color(0xFF4A4B7E);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              spreadRadius: 0,
              offset: Offset(0, 4),
              color: Colors.black12,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: [
            Icon(icon, size: 28, color: iconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F1F2D),
                    ),
                    child: SizedBox(),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F1F2D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    valueText,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF4A4B7E),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// HERO ART WIDGETS ------------------------------------------------------------

class _BrainBoltLogo extends StatelessWidget {
  const _BrainBoltLogo();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/logo.svg',
      height: 80,
      width: 80,
      fit: BoxFit.contain,
    );
  }
}

/// Page 2 hero image (tiles)
class _TimingPreviewArt extends StatelessWidget {
  const _TimingPreviewArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 240, minHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/images/tiles.jpg', fit: BoxFit.cover),
    );
  }
}

/// Page 3 hero image (feedback)
class _FeedbackPreviewArt extends StatelessWidget {
  const _FeedbackPreviewArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 240, minHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/images/feedback.jpg', fit: BoxFit.cover),
    );
  }
}
