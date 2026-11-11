import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';
import 'buttons.dart';

/// What a list shows when it has nothing: an icon, a title, a sentence and
/// optionally one action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(NamoSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: p.backgroundAlt, shape: BoxShape.circle),
                child: Icon(icon,
                    size: NamoSizes.icon,
                    weight: 300,
                    fill: 0,
                    color: p.textSecondary),
              ),
              const SizedBox(height: NamoSpace.lg),
              Text(title,
                  textAlign: TextAlign.center,
                  style: NamoType.cardTitle(p.text)),
              if (message != null) ...[
                const SizedBox(height: NamoSpace.sm),
                Text(message!,
                    textAlign: TextAlign.center,
                    style: NamoType.body(p.textSecondary)),
              ],
              if (actionLabel != null) ...[
                const SizedBox(height: NamoSpace.xl),
                PrimaryButton(label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
