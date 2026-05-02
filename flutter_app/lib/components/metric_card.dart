import 'package:flutter/material.dart';
import '../design_tokens/tokens.dart';
import 'progress_ring.dart';

/// MetricCard Component
/// Displays stats and achievements with optional trend indicator
/// Used for: Workout stats, achievements, progress tracking

enum MetricCardVariant {
  standard,
  compact,
  large,
}

enum TrendDirection {
  up,
  down,
  neutral,
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.sublabel,
    this.trend,
    this.trendValue,
    this.variant = MetricCardVariant.standard,
    this.icon,
    this.color,
    this.onTap,
    this.isLoading = false,
  });

  final String value;
  final String label;
  final String? unit;
  final String? sublabel;
  final TrendDirection? trend;
  final String? trendValue;
  final MetricCardVariant variant;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: _getPadding(),
        decoration: BoxDecoration(
          color: TitanColors.surface700,
          borderRadius: BorderRadius.circular(TitanRadius.radius16),
          border: Border.all(
            color: TitanColors.surface500.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: TitanElevation.shadow1,
        ),
        child: isLoading
            ? _buildLoadingState()
            : _buildContent(),
      ),
    );
  }

  EdgeInsetsGeometry _getPadding() {
    switch (variant) {
      case MetricCardVariant.compact:
        return const EdgeInsets.all(TitanSpacing.space12);
      case MetricCardVariant.large:
        return const EdgeInsets.all(TitanSpacing.space24);
      case MetricCardVariant.standard:
        return const EdgeInsets.all(TitanSpacing.space16);
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: TitanLoadingRing(
        size: variant == MetricCardVariant.large ? 32 : 24,
      ),
    );
  }

  Widget _buildContent() {
    switch (variant) {
      case MetricCardVariant.compact:
        return _buildCompactContent();
      case MetricCardVariant.large:
        return _buildLargeContent();
      case MetricCardVariant.standard:
        return _buildStandardContent();
    }
  }

  Widget _buildStandardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(TitanSpacing.space8),
            decoration: BoxDecoration(
              color: (color ?? TitanColors.primary500).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(TitanRadius.radius8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: color ?? TitanColors.primary500,
            ),
          ),
          const SizedBox(height: TitanSpacing.space12),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: TitanTypography.fontFamilyMetric,
                fontSize: TitanTypography.fontSize32,
                fontWeight: TitanTypography.weightBold,
                color: TitanColors.text900,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: TitanSpacing.space4),
              Text(
                unit!,
                style: const TextStyle(
                  fontFamily: TitanTypography.fontFamilyUI,
                  fontSize: TitanTypography.fontSize14,
                  color: TitanColors.text600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: TitanSpacing.space4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: TitanTypography.fontFamilyUI,
            fontSize: TitanTypography.fontSize14,
            color: TitanColors.text700,
          ),
        ),
        if (trend != null || sublabel != null) ...[
          const SizedBox(height: TitanSpacing.space8),
          _buildTrendIndicator(),
        ],
      ],
    );
  }

  Widget _buildCompactContent() {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 18,
            color: color ?? TitanColors.primary500,
          ),
          const SizedBox(width: TitanSpacing.space8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontFamily: TitanTypography.fontFamilyMetric,
                      fontSize: TitanTypography.fontSize20,
                      fontWeight: TitanTypography.weightBold,
                      color: TitanColors.text900,
                    ),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: TitanSpacing.space2),
                    Text(
                      unit!,
                      style: const TextStyle(
                        fontFamily: TitanTypography.fontFamilyUI,
                        fontSize: TitanTypography.fontSize12,
                        color: TitanColors.text600,
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: TitanTypography.fontFamilyUI,
                  fontSize: TitanTypography.fontSize12,
                  color: TitanColors.text600,
                ),
              ),
            ],
          ),
        ),
        if (trend != null) _buildTrendBadge(),
      ],
    );
  }

  Widget _buildLargeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (icon != null)
              Container(
                padding: const EdgeInsets.all(TitanSpacing.space12),
                decoration: BoxDecoration(
                  color: (color ?? TitanColors.primary500).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(TitanRadius.radius12),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: color ?? TitanColors.primary500,
                ),
              )
            else
              const SizedBox.shrink(),
            if (trend != null) _buildTrendBadge(),
          ],
        ),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: TitanTypography.fontFamilyMetric,
                fontSize: 48,
                fontWeight: TitanTypography.weightBold,
                color: TitanColors.text900,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: TitanSpacing.space8),
              Text(
                unit!,
                style: const TextStyle(
                  fontFamily: TitanTypography.fontFamilyUI,
                  fontSize: TitanTypography.fontSize18,
                  color: TitanColors.text600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: TitanSpacing.space8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: TitanTypography.fontFamilyUI,
            fontSize: TitanTypography.fontSize16,
            color: TitanColors.text700,
          ),
        ),
        if (sublabel != null) ...[
          const SizedBox(height: TitanSpacing.space4),
          Text(
            sublabel!,
            style: const TextStyle(
              fontFamily: TitanTypography.fontFamilyUI,
              fontSize: TitanTypography.fontSize14,
              color: TitanColors.text600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTrendIndicator() {
    if (trend == null && sublabel == null) return const SizedBox.shrink();
    
    return Row(
      children: [
        if (trend != null) ...[
          Icon(
            trend == TrendDirection.up
                ? Icons.trending_up_rounded
                : trend == TrendDirection.down
                    ? Icons.trending_down_rounded
                    : Icons.trending_flat_rounded,
            size: 16,
            color: _getTrendColor(),
          ),
          if (trendValue != null) ...[
            const SizedBox(width: TitanSpacing.space4),
            Text(
              trendValue!,
              style: TextStyle(
                fontFamily: TitanTypography.fontFamilyUI,
                fontSize: TitanTypography.fontSize12,
                fontWeight: TitanTypography.weightMedium,
                color: _getTrendColor(),
              ),
            ),
          ],
        ],
        if (sublabel != null) ...[
          if (trend != null) const SizedBox(width: TitanSpacing.space8),
          Text(
            sublabel!,
            style: const TextStyle(
              fontFamily: TitanTypography.fontFamilyUI,
              fontSize: TitanTypography.fontSize12,
              color: TitanColors.text600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTrendBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TitanSpacing.space8,
        vertical: TitanSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: _getTrendColor().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(TitanRadius.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            trend == TrendDirection.up
                ? Icons.arrow_upward_rounded
                : trend == TrendDirection.down
                    ? Icons.arrow_downward_rounded
                    : Icons.remove_rounded,
            size: 12,
            color: _getTrendColor(),
          ),
          if (trendValue != null) ...[
            const SizedBox(width: TitanSpacing.space4),
            Text(
              trendValue!,
              style: TextStyle(
                fontFamily: TitanTypography.fontFamilyUI,
                fontSize: TitanTypography.fontSize12,
                fontWeight: TitanTypography.weightMedium,
                color: _getTrendColor(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getTrendColor() {
    switch (trend) {
      case TrendDirection.up:
        return TitanColors.statusSuccess;
      case TrendDirection.down:
        return TitanColors.statusError;
      case TrendDirection.neutral:
        return TitanColors.text600;
      case null:
        return TitanColors.text600;
    }
  }
}

/// A grid of metric cards for dashboard displays
class MetricCardGrid extends StatelessWidget {
  const MetricCardGrid({
    super.key,
    required this.metrics,
    this.crossAxisCount = 2,
    this.spacing = TitanSpacing.space16,
  });

  final List<MetricCard> metrics;
  final int crossAxisCount;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: 1.5,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) => metrics[index],
    );
  }
}