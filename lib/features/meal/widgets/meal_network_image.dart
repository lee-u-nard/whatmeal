import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/unsplash_service.dart';

/// One bounded, dish-aware image path for previews, cards and details.
class MealNetworkImage extends StatefulWidget {
  const MealNetworkImage(
      {super.key,
      required this.url,
      this.mealTitle,
      this.width,
      this.height,
      this.fit = BoxFit.cover,
      this.borderRadius,
      this.service,
      this.imageProvider,
      this.loadTimeout = const Duration(seconds: 12)});
  final String url;
  final String? mealTitle;
  final double? width, height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final UnsplashService? service;
  final ImageProvider Function(String)? imageProvider;
  final Duration loadTimeout;
  @override
  State<MealNetworkImage> createState() => _MealNetworkImageState();
}

class _MealNetworkImageState extends State<MealNetworkImage> {
  UnsplashService get _service => widget.service ?? UnsplashService.instance;
  UnsplashPhoto? _photo;
  String? _url;
  Timer? _deadline;
  int _request = 0, _attempt = 0;
  bool _loading = false, _hasFrame = false, _recovering = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(MealNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.mealTitle != widget.mealTitle ||
        oldWidget.service != widget.service) {
      _attempt = 0;
      _resolve();
    }
  }

  @override
  void dispose() {
    ++_request;
    _deadline?.cancel();
    super.dispose();
  }

  Future<void> _resolve({bool refresh = false}) async {
    final request = ++_request;
    _deadline?.cancel();
    setState(() {
      _photo = null;
      _url = null;
      _loading = true;
      _hasFrame = false;
      _recovering = false;
    });
    _deadline = Timer(widget.loadTimeout, () => _fail(request));
    final title = widget.mealTitle?.trim();
    final photo = title == null || title.isEmpty
        ? null
        : await _service.fetchMealImage(null,
            mealTitle: title, refresh: refresh);
    if (!mounted || request != _request) return;
    // A bare URL is allowed only for callers with no dish identity. All meal
    // surfaces pass a title and must obtain a matching source reference.
    final url = photo?.smallUrl ??
        ((title == null || title.isEmpty) &&
                UnsplashService.validImageUrl(widget.url)
            ? widget.url
            : null);
    if (url == null) _deadline?.cancel();
    setState(() {
      _photo = photo;
      _url = url;
      _loading = url != null;
    });
  }

  void _fail(int request) {
    if (!mounted || request != _request || _recovering || _hasFrame) return;
    _recovering = true;
    _deadline?.cancel();
    final failed = _url;
    final title = widget.mealTitle;
    if (failed != null && title != null) _service.rejectImage(title, failed);
    if (failed != null && title != null && _attempt++ == 0) {
      _resolve(refresh: true);
    } else {
      ++_request;
      setState(() {
        _url = null;
        _photo = null;
        _loading = false;
      });
    }
  }

  Widget _frame(BuildContext context, Widget child, int? frame, bool sync) {
    if ((frame != null || sync) && !_hasFrame) {
      final request = _request;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || request != _request) return;
        _deadline?.cancel();
        setState(() {
          _hasFrame = true;
          _loading = false;
        });
      });
    }
    return frame == null && !sync
        ? _box(
            child: const Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))))
        : child;
  }

  Widget _error(BuildContext context, Object error, StackTrace? stack) {
    final request = _request;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fail(request));
    return _placeholder();
  }

  Future<void> _credit() async {
    final photo = _photo;
    if (photo == null) return;
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Photo credit'),
              content: Text(
                  '${photo.photographerName}\n${photo.sourceName}\n${photo.license}'),
              actions: [
                TextButton(
                    onPressed: () async {
                      final uri = Uri.tryParse(photo.unsplashPageUrl);
                      if (uri != null && uri.scheme == 'https') {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: const Text('Source and license')),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final Widget image = _url == null
        ? (_loading
            ? _box(
                child: const Center(
                    child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))))
            : _placeholder())
        : widget.imageProvider == null
            ? Image.network(_url!,
                width: widget.width,
                height: widget.height,
                fit: widget.fit,
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                frameBuilder: _frame,
                errorBuilder: _error)
            : Image(
                image: widget.imageProvider!(_url!),
                width: widget.width,
                height: widget.height,
                fit: widget.fit,
                frameBuilder: _frame,
                errorBuilder: _error);
    final credited = _photo != null && _hasFrame
        ? Stack(children: [
            image,
            Positioned(
                right: 0,
                bottom: 0,
                child: Tooltip(
                    message:
                        'Photo: ${_photo!.photographerName} - ${_photo!.sourceName}',
                    child: Material(
                        color: Colors.black54,
                        child: InkWell(
                            onTap: _credit,
                            child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.info_outline,
                                    color: Colors.white, size: 16))))))
          ])
        : image;
    return widget.borderRadius == null
        ? credited
        : ClipRRect(borderRadius: widget.borderRadius!, child: credited);
  }

  Widget _box({required Widget child}) => Container(
      width: widget.width,
      height: widget.height,
      color: AppColors.primaryLight,
      child: child);
  Widget _placeholder() => _box(
      child: Semantics(
          label: 'Dish image unavailable',
          child: Center(
              child: IconButton(
                  tooltip: 'Retry dish image',
                  onPressed: () {
                    _attempt = 0;
                    _resolve(refresh: true);
                  },
                  icon: Icon(Icons.restaurant,
                      color: AppColors.primary,
                      size: widget.height != null && widget.height! < 80
                          ? 28
                          : 40)))));
}
