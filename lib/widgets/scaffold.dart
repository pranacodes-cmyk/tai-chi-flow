import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Screen container: background colour + status-bar icon tone (web Screen tone).
/// [lightIcons] = true means light status-bar icons (for dark/immersive screens).
class EnsoScaffold extends StatelessWidget {
  const EnsoScaffold({
    super.key,
    required this.body,
    this.background = C.cream,
    this.lightIcons = false,
    this.gradient,
    this.resizeToAvoidBottomInset = true,
  });
  final Widget body;
  final Color background;
  final bool lightIcons;
  final Gradient? gradient;
  final bool resizeToAvoidBottomInset;
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          (lightIcons ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: lightIcons
                    ? Brightness.light
                    : Brightness.dark,
              ),
      child: Scaffold(
        backgroundColor: background,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: gradient == null
            ? body
            : DecoratedBox(
                decoration: BoxDecoration(gradient: gradient),
                child: body,
              ),
      ),
    );
  }
}

/// Top safe-area spacer.
double topInset(BuildContext context) => MediaQuery.paddingOf(context).top;
double bottomInset(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom;

/// Horizontal scroller with 24px gutters.
class HScroll extends StatelessWidget {
  const HScroll({
    super.key,
    required this.children,
    this.gap = 14,
    this.padding = 24,
    this.height,
  });
  final List<Widget> children;
  final double gap;
  final double padding;
  final double? height;
  @override
  Widget build(BuildContext context) {
    final list = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: padding).copyWith(bottom: 8),
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            children[i],
          ],
        ],
      ),
    );
    return height == null ? list : SizedBox(height: height, child: list);
  }
}
