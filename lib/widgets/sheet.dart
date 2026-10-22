import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Bottom sheet matching the web `Sheet` (34px top radius, grab handle, drag to dismiss).
Future<T?> showEnsoSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dark = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: C.ink.withValues(alpha: 0.4),
    elevation: 0,
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      final kb = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: kb),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.92,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: dark ? C.forest2 : C.cream,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(34),
              ),
              boxShadow: S.float,
            ),
            padding: EdgeInsets.only(bottom: bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 40,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dark
                          ? C.ivory.withValues(alpha: 0.25)
                          : C.ink.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Flexible(
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: dark ? C.ivory : C.ink),
                    child: SingleChildScrollView(child: builder(ctx)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
