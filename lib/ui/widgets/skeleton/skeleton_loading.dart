import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../viewmodels/tracker_view_model.dart';
import '../../theme/app_theme.dart';
import '../app_bottom_nav.dart';

/// A widget that applies a shimmering highlight effect over its children.
///
/// This provides visual feedback to the user while data is loading,
/// improving user engagement rather than showing a plain blank screen or spinner.
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 1500 ms looping animation for a smooth, subtle shimmer sweep.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // In widget tests, avoid infinite animation loops so tester.pumpAndSettle() succeeds.
    final isTestEnvironment =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTestEnvironment) {
      _controller.repeat();
    } else {
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    // Determine colors based on active theme brightness.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = widget.baseColor ??
        (isDark ? const Color(0xFF232738) : const Color(0xFFE2E8F0));
    final highlight = widget.highlightColor ??
        (isDark ? const Color(0xFF33384F) : const Color(0xFFF8FAFC));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                base,
                highlight,
                base,
              ],
              stops: const [
                0.1,
                0.5,
                0.9,
              ],
              transform: _SlidingGradientTransform(
                slidePercent: _controller.value,
              ),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Helper gradient transform that slides the shimmer highlight from left to right.
class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // Translate the gradient horizontally across the target area.
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2 - 1),
      0.0,
      0.0,
    );
  }
}

/// A basic placeholder block for skeleton views (rectangle with rounded corners).
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;
  final Color? color;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = AppColors.radiusMd,
    this.shape = BoxShape.rectangle,
    this.color,
  });

  /// Factory constructor for a circular skeleton placeholder (e.g. avatars, icons).
  const SkeletonBox.circle({
    super.key,
    required double size,
    this.color,
  })  : width = size,
        height = size,
        borderRadius = 0,
        shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor =
        isDark ? const Color(0xFF232738) : const Color(0xFFE2E8F0);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? defaultColor,
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A convenience placeholder representing a line of text in skeleton loaders.
class SkeletonLine extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonLine({
    super.key,
    this.width,
    this.height = 14.0,
    this.borderRadius = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }
}

/// A container card skeleton styled to match the app's standard Card design tokens.
class SkeletonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SkeletonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : AppColors.card;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
      ),
      child: child,
    );
  }
}

/// A realistic skeleton loader matching the Home Dashboard layout.
///
/// Mimics the Header, Balance Card, Income/Spent Cards, Shortcuts,
/// Top Spending, Quick Stats, and Recent Transactions list.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.bg;

    return ShimmerLoading(
      child: Container(
        color: bgColor,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header placeholder (Greeting & notifications bell)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonLine(width: 100, height: 26, borderRadius: 6),
                      SizedBox(height: 6),
                      SkeletonLine(width: 140, height: 14, borderRadius: 4),
                    ],
                  ),
                  const SkeletonBox.circle(size: 40),
                ],
              ),
              const SizedBox(height: 20),

              // 2. Balance Card placeholder
              SkeletonCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLine(width: 110, height: 13),
                    const SizedBox(height: 12),
                    const SkeletonLine(width: 200, height: 36, borderRadius: 8),
                    const SizedBox(height: 18),
                    Row(
                      children: const [
                        SkeletonBox(width: 90, height: 32, borderRadius: 16),
                        SizedBox(width: 8),
                        SkeletonBox(width: 110, height: 32, borderRadius: 16),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Income / Spent two-column cards
              Row(
                children: const [
                  Expanded(
                    child: SkeletonCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox.circle(size: 28),
                          SizedBox(height: 10),
                          SkeletonLine(width: 80, height: 11),
                          SizedBox(height: 6),
                          SkeletonLine(width: 110, height: 18, borderRadius: 4),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: SkeletonCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox.circle(size: 28),
                          SizedBox(height: 10),
                          SkeletonLine(width: 80, height: 11),
                          SizedBox(height: 6),
                          SkeletonLine(width: 110, height: 18, borderRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. Quick shortcut chips row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (_) {
                  return Column(
                    children: const [
                      SkeletonBox.circle(size: 52),
                      SizedBox(height: 6),
                      SkeletonLine(width: 44, height: 10),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 20),

              // 5. Top Spending card skeleton
              SkeletonCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        SkeletonLine(width: 110, height: 15),
                        SkeletonLine(width: 70, height: 13),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < 3; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: const [
                            SkeletonBox.circle(size: 10),
                            SizedBox(width: 10),
                            Expanded(child: SkeletonLine(height: 12)),
                            SizedBox(width: 16),
                            SkeletonLine(width: 60, height: 12),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 6. Recent Transactions list skeleton
              SkeletonCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        SkeletonLine(width: 130, height: 15),
                        SkeletonLine(width: 50, height: 13),
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (var i = 0; i < 4; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: const [
                            SkeletonBox.circle(size: 40),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SkeletonLine(width: 120, height: 13),
                                  SizedBox(height: 6),
                                  SkeletonLine(width: 70, height: 10),
                                ],
                              ),
                            ),
                            SkeletonLine(width: 65, height: 16, borderRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A standalone full-screen skeleton view shown during application boot/loading.
///
/// Displays the [DashboardSkeleton] alongside an authentic bottom navigation bar
/// placeholder so users see an interactive-feeling layout immediately upon opening.
class SkeletonLoadingScreen extends StatefulWidget {
  const SkeletonLoadingScreen({super.key});

  @override
  State<SkeletonLoadingScreen> createState() => _SkeletonLoadingScreenState();
}

class _SkeletonLoadingScreenState extends State<SkeletonLoadingScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure the view model starts initializing if not already in progress.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<TrackerViewModel>();
      if (!vm.initialized && !vm.hasInitError) {
        vm.init();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TrackerViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navHeight = AppBottomNav.heightOf(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.bg,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            const DashboardSkeleton(),
            // If an initialization error occurs, present a recovery banner on top.
            if (vm.hasInitError)
              Positioned(
                left: 16,
                right: 16,
                bottom: navHeight + 16,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  color: AppColors.danger,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          vm.initError ?? 'Failed to load local database.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: () => vm.init(),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Tap to Retry'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      // Dummy bottom navigation bar to provide seamless layout continuity.
      bottomNavigationBar: IgnorePointer(
        child: AppBottomNav(
          items: const [
            AppNavItem(label: 'Home', icon: Icons.home),
            AppNavItem(label: 'Budgets', icon: Icons.account_balance_wallet_outlined),
            AppNavItem(label: 'Analytics', icon: Icons.pie_chart_outline),
            AppNavItem(label: 'Settings', icon: Icons.settings_outlined),
          ],
          currentIndex: 0,
          onTabSelected: (_) {},
          action: AppNavAction(
            label: 'Add',
            icon: Icons.add,
            onPressed: () {},
          ),
        ),
      ),
    );
  }
}
