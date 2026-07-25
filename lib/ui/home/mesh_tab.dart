import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/mesh/mesh_ports.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import '../format.dart';

/// A window into the delay-tolerant network itself: how many peers are in
/// range, how many messages this device is carrying for others, and a live
/// feed of routing decisions. It turns the invisible mesh into something you
/// can watch work.
class MeshTab extends StatelessWidget {
  const MeshTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatService service = context.watch<ChatService>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _StatCard(
                icon: Icons.wifi_tethering,
                value: '${service.onlinePeerCount}',
                label: 'Peers in range',
                color: service.onlinePeerCount > 0
                    ? AppColors.online
                    : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.inventory_2_outlined,
                value: '${service.carriedForOthers}',
                label: 'Carrying for others',
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _HowItWorksCard(),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            const Icon(Icons.timeline, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Live activity',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              '${service.activityLog.length} events',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (service.activityLog.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Nothing yet. Routing events appear here as messages flow.',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          )
        else
          ...service.activityLog.take(60).map((MeshEvent e) => _EventRow(e)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.hub_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              const Text(
                'How your messages travel',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _Step(
            '1',
            'Sent to the mesh',
            'Your phone floods the message to every phone in range.',
          ),
          const _Step(
            '2',
            'Carried onward',
            'Each phone relays and carries it, hopping closer to the recipient.',
          ),
          const _Step(
            '3',
            'Delivered + acked',
            'The recipient receives it and sends a receipt back the same way.',
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.title, this.body);
  final String n;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 11,
            backgroundColor: scheme.primary,
            child: Text(
              n,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow(this.event);
  final MeshEvent event;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = _visual(event.type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _humanize(event),
              style: const TextStyle(fontSize: 12.5, height: 1.3),
            ),
          ),
          Text(
            relativeTime(event.ts),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  String _humanize(MeshEvent e) {
    switch (e.type) {
      case MeshEventType.received:
        return 'Received an envelope';
      case MeshEventType.duplicateDropped:
        return 'Dropped a duplicate (already seen)';
      case MeshEventType.delivered:
        return 'Delivered to its destination';
      case MeshEventType.relayed:
        return 'Relayed onward toward the recipient';
      case MeshEventType.ttlExpired:
        return 'Dropped - hop limit reached';
      case MeshEventType.cacheEvicted:
        return 'Freed carried storage (${e.detail})';
      case MeshEventType.ackEmitted:
        return 'Sent a delivery receipt';
      case MeshEventType.carryCleared:
        return 'Stopped carrying an acknowledged message';
      case MeshEventType.cacheFlushed:
        return 'Handed carried messages to a new peer';
    }
  }

  (IconData, Color) _visual(MeshEventType t) {
    switch (t) {
      case MeshEventType.received:
        return (Icons.call_received, Colors.blueGrey);
      case MeshEventType.duplicateDropped:
        return (Icons.filter_alt_outlined, Colors.grey);
      case MeshEventType.delivered:
        return (Icons.done_all, AppColors.delivered);
      case MeshEventType.relayed:
        return (Icons.alt_route, AppColors.brand);
      case MeshEventType.ttlExpired:
        return (Icons.block, Colors.redAccent);
      case MeshEventType.cacheEvicted:
        return (Icons.delete_sweep_outlined, Colors.orange);
      case MeshEventType.ackEmitted:
        return (Icons.mark_email_read_outlined, AppColors.online);
      case MeshEventType.carryCleared:
        return (Icons.check_circle_outline, AppColors.online);
      case MeshEventType.cacheFlushed:
        return (Icons.outbox_outlined, AppColors.accent);
    }
  }
}
