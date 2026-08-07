import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../widgets/seamless.dart';
import '../session/session_page.dart';

class Device {
  const Device(this.name, this.os, this.pingMs);
  final String name;
  final String os;
  final int? pingMs;
}

const _devices = [
  Device('GAMING-RIG', 'Windows 11 · RTX 4070', 24),
  Device('OFFICE-PC', 'Windows 10', null),
  Device('LAPTOP-ASUS', 'Ubuntu 24.04', 18),
  Device('MAC-STUDIO', 'macOS 15', 72),
];

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 60,
        bottom: 110,
      ),
      children: [
        for (final d in _devices) ...[
          _DeviceCard(device: d, primary: d == _devices.first),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, this.primary = false});

  final Device device;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final offline = device.pingMs == null;

    return SurfaceCard(
      dim: offline,
      onTap: offline
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SessionPage(
                      deviceName: device.name, deviceId: '123 456 789'),
                ),
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: c.textHi)),
                    const SizedBox(height: 3),
                    Text(device.os,
                        style: TextStyle(fontSize: 11.5, color: c.textLow)),
                  ],
                ),
              ),
              Row(
                children: [
                  StatusDot(pingMs: device.pingMs),
                  const SizedBox(width: 6),
                  Text(offline ? 'offline' : '${device.pingMs} ms',
                      style: TextStyle(fontSize: 11, color: c.textMid)),
                ],
              ),
            ],
          ),
          if (primary) ...[
            const SizedBox(height: Gap.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Lanjutkan sesi',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: c.accent)),
                Icon(Icons.arrow_forward_rounded, size: 14, color: c.accent),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
