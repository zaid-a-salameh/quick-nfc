/// Bounded adaptive typography helper and widget guaranteeing readable text
/// without mid-word truncation up to a strict minimum font floor.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/widgets/lang_roll_text.dart';

/// Measures [text] across [candidateSizes] (descending) inside [maxWidth] and
/// optional [maxHeight] / [maxLines] using [TextPainter].
///
/// Returns the largest candidate size that fits cleanly, or falls back to the
/// last (floor) size flagged with `didOverflow: true`.
({double fontSize, bool didOverflow}) resolveBoundedFontSize({
  required String text,
  required TextStyle baseStyle,
  required double maxWidth,
  required int maxLines,
  required List<double> candidateSizes,
  required TextDirection textDirection,
  double? maxHeight,
  Locale? locale,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  assert(candidateSizes.isNotEmpty, 'candidateSizes must not be empty');
  if (!maxWidth.isFinite || maxWidth <= 0) {
    return (fontSize: candidateSizes.first, didOverflow: false);
  }

  final safeMaxWidth = math.max(0.0, maxWidth - 2.0);
  final checkHeight = maxHeight != null && maxHeight.isFinite && maxHeight > 0;

  for (final size in candidateSizes) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: baseStyle.copyWith(fontSize: size),
      ),
      textDirection: textDirection,
      locale: locale,
      maxLines: maxLines,
      textScaler: textScaler,
    )..layout(maxWidth: safeMaxWidth);

    final fitsLines = !painter.didExceedMaxLines;
    final fitsHeight = !checkHeight || painter.height <= maxHeight + 0.5;
    painter.dispose();
    if (fitsLines && fitsHeight) {
      return (fontSize: size, didOverflow: false);
    }
  }

  return (fontSize: candidateSizes.last, didOverflow: true);
}

/// Renders [LangRollText] at the largest font size in [candidateSizes] that
/// fits the available width and height within [maxLines], preserving a readable
/// floor.
class BoundedAdaptiveText extends StatelessWidget {
  const BoundedAdaptiveText(
    this.text, {
    super.key,
    required this.baseStyle,
    required this.maxLines,
    required this.candidateSizes,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle baseStyle;
  final int maxLines;
  final List<double> candidateSizes;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final rawScaler = MediaQuery.textScalerOf(context);
    final clampedScaler = rawScaler.clamp(
      minScaleFactor: 0.9,
      maxScaleFactor: 1.08,
    );
    final mergedStyle = DefaultTextStyle.of(context).style.merge(baseStyle);

    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 0.9,
      maxScaleFactor: 1.08,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final resolved = resolveBoundedFontSize(
            text: text,
            baseStyle: mergedStyle,
            maxWidth: constraints.maxWidth,
            maxHeight: constraints.maxHeight,
            maxLines: maxLines,
            candidateSizes: candidateSizes,
            textDirection: textDirection,
            locale: locale,
            textScaler: clampedScaler,
          );

          return LangRollText(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: mergedStyle.copyWith(fontSize: resolved.fontSize),
          );
        },
      ),
    );
  }
}
