import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../theme/tokens.dart';

/// iOS-style switch matching the web `Switch`.
class EnsoSwitch extends StatelessWidget {
  const EnsoSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      child: GestureDetector(
        onTap: () {
          Haptics.select();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 51,
          height: 31,
          decoration: BoxDecoration(
            color: value ? C.jade : C.ink.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(31),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 27,
              height: 27,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: C.ivory,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: C.ink.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
