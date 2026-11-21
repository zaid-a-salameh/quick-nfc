import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_link_generator/l10n/app_localizations.dart';
import 'package:review_link_generator/ui/features/home_grid/models/grid_tile_models.dart';
import 'package:review_link_generator/ui/features/home_grid/widgets/bounded_adaptive_text.dart';
import 'package:review_link_generator/ui/features/home_grid/widgets/interactive_home_grid.dart';
import 'package:review_link_generator/ui/features/home_grid/widgets/tool_tile_visuals.dart';

Future<void> _loadAppFonts() async {
  Future<ByteData> loadFile(String relativePath) async {
    final bytes = await File(relativePath).readAsBytes();
    return ByteData.sublistView(bytes);
  }

  final interLoader = FontLoader('Inter')
    ..addFont(loadFile('assets/fonts/Inter-Medium.ttf'))
    ..addFont(loadFile('assets/fonts/Inter-SemiBold.ttf'))
    ..addFont(loadFile('assets/fonts/Inter-Bold.ttf'))
    ..addFont(loadFile('assets/fonts/Inter-ExtraBold.ttf'));
  await interLoader.load();

  final cairoLoader = FontLoader('Cairo')
    ..addFont(loadFile('assets/fonts/Cairo-SemiBold.ttf'))
    ..addFont(loadFile('assets/fonts/Cairo-Bold.ttf'))
    ..addFont(loadFile('assets/fonts/Cairo-ExtraBold.ttf'));
  await cairoLoader.load();
}

double _measureHeight({
  required String text,
  required TextStyle style,
  required double maxWidth,
  required int maxLines,
  required TextDirection textDirection,
  required Locale locale,
  required TextScaler textScaler,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
    locale: locale,
    maxLines: maxLines,
    textScaler: textScaler,
  )..layout(maxWidth: maxWidth - 2.0);
  final h = painter.height;
  painter.dispose();
  return h;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const innerWidth = 300.0;
  const colWidth = (innerWidth - 2 * InteractiveHomeGrid.gridGap) / 3;
  const twoColWidth = 2 * colWidth + InteractiveHomeGrid.gridGap;
  const threeColWidth = innerWidth;

  // Inner horizontal text widths accounting for borders, padding, badges, gaps & chevrons.
  const oneByOneTextWidth = colWidth - 16.0;
  const twoByOneTextWidth = twoColWidth - 77.0;
  const threeByOneTextWidth = threeColWidth - 104.0;
  const twoByTwoTextWidth = twoColWidth - 26.0;
  const threeByTwoTextWidth = threeColWidth - 30.0;
  const toolsHubRowTextWidth = 177.8;

  test(
    'every tool title and subtitle fits cleanly without ellipsis across all 10 locales at 360dp phone width (1.0x & 1.08x text scales)',
    () async {
      await _loadAppFonts();
      final failures = <String>[];

      for (final scale in const <double>[1.0, 1.08]) {
        final scaler = TextScaler.linear(scale);

        for (final locale in AppLocalizations.supportedLocales) {
          final l10n = lookupAppLocalizations(locale);
          final isArabic = locale.languageCode == 'ar';
          final dir = isArabic ? TextDirection.rtl : TextDirection.ltr;
          final fontFamily = isArabic ? 'Cairo' : 'Inter';

          for (final id in HomeToolId.values) {
            final presentation = ToolTileVisuals.resolve(id, l10n);

            // 1. 3x1: Title (maxLines 1) & Subtitle (maxLines 2, height-constrained)
            final title3x1Style = TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w800,
              height: 1.18,
            );
            final title3x1 = resolveBoundedFontSize(
              text: presentation.title,
              baseStyle: title3x1Style,
              maxWidth: threeByOneTextWidth,
              maxLines: 1,
              candidateSizes: const <double>[14.5, 13.6, 12.8],
              textDirection: dir,
              locale: locale,
              textScaler: scaler,
            );
            if (title3x1.didOverflow) {
              failures.add(
                '${locale.languageCode}@${scale}x 3x1 title [${id.storageKey}]: "${presentation.title}"',
              );
            }
            final title3x1Height = _measureHeight(
              text: presentation.title,
              style: title3x1Style.copyWith(fontSize: title3x1.fontSize),
              maxWidth: threeByOneTextWidth,
              maxLines: 1,
              textDirection: dir,
              locale: locale,
              textScaler: scaler,
            );
            final sub3x1MaxHeight = 62.0 - title3x1Height - 1.0;
            final sub3x1 = resolveBoundedFontSize(
              text: presentation.subtitle,
              baseStyle: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.w500,
                height: 1.15,
              ),
              maxWidth: threeByOneTextWidth,
              maxHeight: sub3x1MaxHeight,
              maxLines: 2,
              candidateSizes: const <double>[11.6, 11.2, 10.8, 10.4],
              textDirection: dir,
              locale: locale,
              textScaler: scaler,
            );
            if (sub3x1.didOverflow) {
              failures.add(
                '${locale.languageCode}@${scale}x 3x1 subtitle [${id.storageKey}] (hAvail=${sub3x1MaxHeight.toStringAsFixed(1)}): "${presentation.subtitle}"',
              );
            }

            // 2. 2x2: Title (maxLines 2) & Subtitle (maxLines 3, height-constrained)
            final title2x2Style = TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w800,
              height: 1.18,
            );
            final title2x2 = resolveBoundedFontSize(
              text: presentation.title,
              baseStyle: title2x2Style,
              maxWidth: twoByTwoTextWidth,
              maxLines: 2,
              candidateSizes: const <double>[14.5, 13.5, 12.6],
              textDirection: dir,
              locale: locale,
              textScaler: scaler,
            );
            if (title2x2.didOverflow) {
              failures.add(
                '${locale.languageCode}@${scale}x 2x2 title [${id.storageKey}]: "${presentation.title}"',
              );
            }
            final title2x2Height = _measureHeight(
              text: presentation.title,
              style: title2x2Style.copyWith(fontSize: title2x2.fontSize),
              maxWidth: twoByTwoTextWidth,
              maxLines: 2,
              textDirection: dir,
              locale: locale,
              textScaler: scaler,
            );
            // 162 - 2 (border) - 24 (pad) - 42 (badge row) - 4 (spacer) = 90.0
            final sub2x2MaxHeight = 90.0 - title2x2Height - 3.0;
            final sub2x2 = resolveBoundedFontSize(
              text: presentation.subtitle,
              baseStyle: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.w500,
                height: 1.16,
              ),
              maxWidth: twoByTwoTextWidth,
              maxHeight: sub2x2MaxHeight,
              maxLines: 3,
              candidateSizes: const <double>[11.6, 11.2, 10.8, 10.4],
              textDirection: dir,
              locale: locale,
              textScaler: scaler,
            );
            if (sub2x2.didOverflow) {
              failures.add(
                '${locale.languageCode}@${scale}x 2x2 subtitle [${id.storageKey}] (hAvail=${sub2x2MaxHeight.toStringAsFixed(1)}): "${presentation.subtitle}"',
              );
            }

            // 3. 3x2: Title (maxLines 2) & Subtitle (maxLines 3, height-constrained)
            final title3x2Style = TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w800,
              height: 1.18,
            );
            final title3x2 = resolveBoundedFontSize(
              text: presentation.title,
              baseStyle: title3x2Style,
              maxWidth: threeByTwoTextWidth,
              maxLines: 2,
              candidateSizes: const <double>[16.0, 15.0, 14.0],
              textDirection: dir,
              locale: locale,
              textScaler: scaler,
            );
            if (title3x2.didOverflow) {
              failures.add(
                '${locale.languageCode}@${scale}x 3x2 title [${id.storageKey}]: "${presentation.title}"',
              );
            }
            final title3x2Height = _measureHeight(
              text: presentation.title,
              style: title3x2Style.copyWith(fontSize: title3x2.fontSize),
              maxWidth: threeByTwoTextWidth,
              maxLines: 2,
              textDirection: dir,
              locale: locale,
              textScaler: scaler,
            );
            // 162 - 2 (border) - 28 (pad) - 48 (badge row) - 4 (spacer) = 80.0
            final sub3x2MaxHeight = 80.0 - title3x2Height - 3.0;
            final sub3x2 = resolveBoundedFontSize(
              text: presentation.subtitle,
              baseStyle: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.w500,
                height: 1.16,
              ),
              maxWidth: threeByTwoTextWidth,
              maxHeight: sub3x2MaxHeight,
              maxLines: 3,
              candidateSizes: const <double>[12.4, 11.8, 11.2, 10.6],
              textDirection: dir,
              locale: locale,
              textScaler: scaler,
            );
            if (sub3x2.didOverflow) {
              failures.add(
                '${locale.languageCode}@${scale}x 3x2 subtitle [${id.storageKey}] (hAvail=${sub3x2MaxHeight.toStringAsFixed(1)}): "${presentation.subtitle}"',
              );
            }

            // 4. 2x1: Title (maxLines 2)
            final title2x1 = resolveBoundedFontSize(
              text: presentation.title,
              baseStyle: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.w800,
                height: 1.18,
              ),
              maxWidth: twoByOneTextWidth,
              maxLines: 2,
              candidateSizes: const <double>[13.8, 13.0, 12.2, 11.5],
              textDirection: dir,
              locale: locale,
              textScaler: scaler,
            );
            if (title2x1.didOverflow) {
              failures.add(
                '${locale.languageCode}@${scale}x 2x1 title [${id.storageKey}]: "${presentation.title}"',
              );
            }

            // 5. 1x1: Title (maxLines 2)
            final title1x1 = resolveBoundedFontSize(
              text: presentation.title,
              baseStyle: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
              maxWidth: oneByOneTextWidth,
              maxLines: 2,
              candidateSizes: const <double>[12.4, 11.8, 11.0],
              textDirection: dir,
              locale: locale,
              textScaler: scaler,
            );
            if (title1x1.didOverflow) {
              failures.add(
                '${locale.languageCode}@${scale}x 1x1 title [${id.storageKey}]: "${presentation.title}"',
              );
            }

            // 6. ToolsHubRowCard: Title (maxLines 1) & Subtitle (maxLines 2)
            final hubTitle = resolveBoundedFontSize(
              text: presentation.title,
              baseStyle: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
              maxWidth: toolsHubRowTextWidth,
              maxLines: 1,
              candidateSizes: const <double>[14.5, 13.6, 12.8],
              textDirection: dir,
              locale: locale,
              textScaler: scaler,
            );
            if (hubTitle.didOverflow) {
              failures.add(
                '${locale.languageCode}@${scale}x hub title [${id.storageKey}]: "${presentation.title}"',
              );
            }

            final hubSub = resolveBoundedFontSize(
              text: presentation.subtitle,
              baseStyle: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.w500,
                height: 1.18,
              ),
              maxWidth: toolsHubRowTextWidth,
              maxLines: 2,
              candidateSizes: const <double>[11.8, 11.4, 11.0, 10.5],
              textDirection: dir,
              locale: locale,
              textScaler: scaler,
            );
            if (hubSub.didOverflow) {
              failures.add(
                '${locale.languageCode}@${scale}x hub subtitle [${id.storageKey}]: "${presentation.subtitle}"',
              );
            }
          }
        }
      }

      expect(
        failures,
        isEmpty,
        reason: 'Overflowing localized strings:\n${failures.join('\n')}',
      );
    },
  );
}
