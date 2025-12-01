import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// 颜色提取结果
class ColorExtractionResult {
  final Color? vibrantColor;
  final Color? mutedColor;
  final Color? dominantColor;
  final Color? lightVibrantColor;
  final Color? darkVibrantColor;
  final Color? lightMutedColor;
  final Color? darkMutedColor;

  const ColorExtractionResult({
    this.vibrantColor,
    this.mutedColor,
    this.dominantColor,
    this.lightVibrantColor,
    this.darkVibrantColor,
    this.lightMutedColor,
    this.darkMutedColor,
  });

  /// 获取主题色（优先级：vibrant > dominant > muted）
  Color? get themeColor => vibrantColor ?? dominantColor ?? mutedColor;

  /// 获取动态背景所需的3个颜色
  List<Color> get dynamicColors {
    final colors = <Color>[];
    
    // 优先使用 vibrant 和 muted 颜色
    if (vibrantColor != null) colors.add(vibrantColor!);
    if (mutedColor != null) colors.add(mutedColor!);
    if (dominantColor != null && colors.length < 3) colors.add(dominantColor!);
    if (lightVibrantColor != null && colors.length < 3) colors.add(lightVibrantColor!);
    if (darkVibrantColor != null && colors.length < 3) colors.add(darkVibrantColor!);
    if (lightMutedColor != null && colors.length < 3) colors.add(lightMutedColor!);
    if (darkMutedColor != null && colors.length < 3) colors.add(darkMutedColor!);
    
    // 如果颜色不足3个，用默认颜色填充
    while (colors.length < 3) {
      colors.add(const Color(0xFF424242)); // Colors.grey[800]
    }
    
    return colors.take(3).toList();
  }
}

/// 颜色提取服务 - 使用 isolate 避免阻塞主线程
class ColorExtractionService {
  static final ColorExtractionService _instance = ColorExtractionService._internal();
  factory ColorExtractionService() => _instance;
  ColorExtractionService._internal();

  // 缓存已提取的颜色
  final Map<String, ColorExtractionResult> _cache = {};
  
  // 正在提取的 URL 集合
  final Set<String> _extractingUrls = {};
  
  // 缓存大小限制
  static const int _maxCacheSize = 50;

  /// 从网络图片 URL 提取颜色（异步，不阻塞主线程）
  Future<ColorExtractionResult?> extractColorsFromUrl(
    String imageUrl, {
    int sampleSize = 32,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (imageUrl.isEmpty) return null;

    // 检查缓存
    if (_cache.containsKey(imageUrl)) {
      return _cache[imageUrl];
    }

    // 检查是否正在提取
    if (_extractingUrls.contains(imageUrl)) {
      // 等待提取完成
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_cache.containsKey(imageUrl)) {
          return _cache[imageUrl];
        }
        if (!_extractingUrls.contains(imageUrl)) {
          break;
        }
      }
      return _cache[imageUrl];
    }

    _extractingUrls.add(imageUrl);

    try {
      // 1. 下载图片数据（在主线程，但使用 http 异步）
      final response = await http.get(Uri.parse(imageUrl)).timeout(timeout);
      if (response.statusCode != 200) {
        debugPrint('⚠️ [ColorExtraction] 图片下载失败: ${response.statusCode}');
        return null;
      }

      final imageBytes = response.bodyBytes;

      // 2. 在 isolate 中解码图片并提取颜色（使用纯 Dart 的 image 包）
      final result = await compute(
        _extractColorsInIsolate,
        _ColorExtractionParams(
          imageBytes: imageBytes,
          sampleSize: sampleSize,
        ),
      );

      if (result != null) {
        // 缓存结果
        _cacheResult(imageUrl, result);
      }

      return result;
    } on TimeoutException {
      debugPrint('⏱️ [ColorExtraction] 图片下载超时: $imageUrl');
      return null;
    } catch (e) {
      debugPrint('⚠️ [ColorExtraction] 颜色提取失败: $e');
      return null;
    } finally {
      _extractingUrls.remove(imageUrl);
    }
  }

  /// 缓存结果
  void _cacheResult(String url, ColorExtractionResult result) {
    // 限制缓存大小
    if (_cache.length >= _maxCacheSize) {
      final keysToRemove = _cache.keys.take(_cache.length - _maxCacheSize + 1).toList();
      for (final key in keysToRemove) {
        _cache.remove(key);
      }
    }
    _cache[url] = result;
  }

  /// 获取缓存的颜色
  ColorExtractionResult? getCachedColors(String imageUrl) {
    return _cache[imageUrl];
  }

  /// 清除缓存
  void clearCache() {
    _cache.clear();
  }
}

/// isolate 参数
class _ColorExtractionParams {
  final Uint8List imageBytes;
  final int sampleSize;

  const _ColorExtractionParams({
    required this.imageBytes,
    required this.sampleSize,
  });
}

/// 在 isolate 中执行的颜色提取函数
/// 使用纯 Dart 的 image 包，可以安全地在 isolate 中运行
ColorExtractionResult? _extractColorsInIsolate(_ColorExtractionParams params) {
  try {
    // 使用 image 包解码图片（纯 Dart，可在 isolate 中运行）
    final image = img.decodeImage(params.imageBytes);
    if (image == null) {
      return null;
    }

    // 缩放图片以提高性能
    final resized = img.copyResize(
      image,
      width: params.sampleSize,
      height: params.sampleSize,
      interpolation: img.Interpolation.average,
    );

    final width = resized.width;
    final height = resized.height;

    // 提取颜色
    final colorCounts = <int, int>{};
    final vibrantCandidates = <int, int>{};
    final mutedCandidates = <int, int>{};

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = resized.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final a = pixel.a.toInt();

        if (a < 128) continue; // 跳过透明像素

        // 量化颜色以减少颜色数量
        final quantizedR = (r ~/ 16) * 16;
        final quantizedG = (g ~/ 16) * 16;
        final quantizedB = (b ~/ 16) * 16;
        final colorValue = (255 << 24) | (quantizedR << 16) | (quantizedG << 8) | quantizedB;

        colorCounts[colorValue] = (colorCounts[colorValue] ?? 0) + 1;

        // 计算饱和度和亮度
        final maxVal = [r, g, b].reduce((a, b) => a > b ? a : b);
        final minVal = [r, g, b].reduce((a, b) => a < b ? a : b);
        final lightness = (maxVal + minVal) / 2 / 255;
        final saturation = maxVal == minVal 
            ? 0.0 
            : (maxVal - minVal) / (255 - (2 * lightness * 255 - 255).abs());

        // 分类颜色
        if (saturation > 0.35 && lightness > 0.2 && lightness < 0.8) {
          vibrantCandidates[colorValue] = (vibrantCandidates[colorValue] ?? 0) + 1;
        } else if (saturation < 0.35 && lightness > 0.2 && lightness < 0.8) {
          mutedCandidates[colorValue] = (mutedCandidates[colorValue] ?? 0) + 1;
        }
      }
    }

    // 找出最常见的颜色
    int? dominantColorValue;
    int? vibrantColorValue;
    int? mutedColorValue;
    int? lightVibrantColorValue;
    int? darkVibrantColorValue;
    int? lightMutedColorValue;
    int? darkMutedColorValue;

    if (colorCounts.isNotEmpty) {
      final sortedColors = colorCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      dominantColorValue = sortedColors.first.key;
    }

    if (vibrantCandidates.isNotEmpty) {
      final sortedVibrant = vibrantCandidates.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      vibrantColorValue = sortedVibrant.first.key;
      
      // 找 light 和 dark vibrant
      for (final entry in sortedVibrant) {
        final colorVal = entry.key;
        final lightness = _getLightnessFromValue(colorVal);
        if (lightness > 0.6 && lightVibrantColorValue == null) {
          lightVibrantColorValue = colorVal;
        } else if (lightness < 0.4 && darkVibrantColorValue == null) {
          darkVibrantColorValue = colorVal;
        }
        if (lightVibrantColorValue != null && darkVibrantColorValue != null) break;
      }
    }

    if (mutedCandidates.isNotEmpty) {
      final sortedMuted = mutedCandidates.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      mutedColorValue = sortedMuted.first.key;
      
      // 找 light 和 dark muted
      for (final entry in sortedMuted) {
        final colorVal = entry.key;
        final lightness = _getLightnessFromValue(colorVal);
        if (lightness > 0.6 && lightMutedColorValue == null) {
          lightMutedColorValue = colorVal;
        } else if (lightness < 0.4 && darkMutedColorValue == null) {
          darkMutedColorValue = colorVal;
        }
        if (lightMutedColorValue != null && darkMutedColorValue != null) break;
      }
    }

    return ColorExtractionResult(
      vibrantColor: vibrantColorValue != null ? Color(vibrantColorValue) : null,
      mutedColor: mutedColorValue != null ? Color(mutedColorValue) : null,
      dominantColor: dominantColorValue != null ? Color(dominantColorValue) : null,
      lightVibrantColor: lightVibrantColorValue != null ? Color(lightVibrantColorValue) : null,
      darkVibrantColor: darkVibrantColorValue != null ? Color(darkVibrantColorValue) : null,
      lightMutedColor: lightMutedColorValue != null ? Color(lightMutedColorValue) : null,
      darkMutedColor: darkMutedColorValue != null ? Color(darkMutedColorValue) : null,
    );
  } catch (e) {
    // 在 isolate 中不能使用 debugPrint，直接返回 null
    return null;
  }
}

/// 从颜色值计算亮度
double _getLightnessFromValue(int colorValue) {
  final r = (colorValue >> 16) & 0xFF;
  final g = (colorValue >> 8) & 0xFF;
  final b = colorValue & 0xFF;
  final maxVal = [r, g, b].reduce((a, b) => a > b ? a : b);
  final minVal = [r, g, b].reduce((a, b) => a < b ? a : b);
  return (maxVal + minVal) / 2 / 255;
}
