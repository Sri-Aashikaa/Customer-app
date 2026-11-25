import 'package:flutter/material.dart';
import '../services/language_service.dart';

/// AppLogo widget that renders the official Sri Aashikaa Raw Milk logo
/// dynamically based on the current app language (English vs Tamil).
class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final double? size;
  final BorderRadius? borderRadius;
  final String? language; // If specified, overrides dynamic language detection
  final bool compact;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.size,
    this.borderRadius,
    this.language,
    this.compact = false,
    this.padding,
    this.backgroundColor,
    this.border,
    this.boxShadow,
    this.fit = BoxFit.contain,
  });

  /// Static helper to get the asset path for a given language code
  static String assetForLanguage(String? lang) {
    if (lang == 'ta') {
      return 'assets/images/logo_ta.png';
    }
    return 'assets/images/logo_en.png';
  }

  @override
  Widget build(BuildContext context) {
    // If language is provided explicitly, use it directly.
    // Otherwise, listen to LanguageService.languageNotifier to update reactively.
    if (language != null) {
      return _buildLogo(language!);
    }

    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.languageNotifier,
      builder: (context, currentLang, _) {
        return _buildLogo(currentLang);
      },
    );
  }

  Widget _buildLogo(String lang) {
    final effectiveW = size ?? width ?? (compact ? 38.0 : 76.0);
    final effectiveH = size ?? height ?? (compact ? 38.0 : 76.0);
    final effectiveRadius = borderRadius ??
        BorderRadius.circular(compact ? 10.0 : 18.0);
    final assetPath = assetForLanguage(lang);

    return Container(
      width: effectiveW,
      height: effectiveH,
      padding: padding ?? EdgeInsets.all(compact ? 3.0 : 8.0),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: effectiveRadius,
        border: border ??
            Border.all(
              color: const Color(0xFFE2E8F0),
              width: compact ? 1.0 : 1.2,
            ),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: compact ? 0.04 : 0.06),
                blurRadius: compact ? 4 : 12,
                offset: Offset(0, compact ? 1 : 4),
              ),
            ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: Image.asset(
          assetPath,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                '🥛',
                style: TextStyle(fontSize: (effectiveH * 0.45).clamp(14, 40)),
              ),
            );
          },
        ),
      ),
    );
  }
}
