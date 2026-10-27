import 'package:flutter/material.dart';

import '../services/verified_display_cache.dart';

class ConnectivityStatusIndicator extends StatelessWidget {
  const ConnectivityStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<FirebaseReachability>(
        valueListenable: VerifiedDisplayCache.reachability,
        builder: (context, _, child) {
          final status = VerifiedDisplayCache.currentReachability;
          final (label, color, icon) = switch (status) {
            FirebaseReachability.online => (
                'Server verified',
                const Color(0xFF287A53),
                Icons.cloud_done
              ),
            FirebaseReachability.unavailable => (
                'Server unavailable',
                const Color(0xFF8A5D26),
                Icons.cloud_off,
              ),
            FirebaseReachability.unknown => (
                'Connection not verified',
                const Color(0xFF665A48),
                Icons.cloud_queue,
              ),
          };
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                label: 'Firebase connection status: $label',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: color),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
