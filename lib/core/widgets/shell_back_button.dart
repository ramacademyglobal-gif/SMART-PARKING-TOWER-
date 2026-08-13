import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:multiparking_tower/routes/app_routes.dart';

/// Leading back control that returns to the member home tab.
///
/// Shell tab roots have no Navigator stack, so the system back affordance is
/// missing — this restores an explicit arrow that jumps to Home.
class ShellBackButton extends StatelessWidget {
  const ShellBackButton({super.key, this.to = AppRoutes.home});

  final String to;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => context.go(to),
    );
  }
}
