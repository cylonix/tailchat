import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ShakeDetector {
  final VoidCallback onPhoneShake;

  final double shakeThresholdGravity;

  final int minTimeBetweenShakes;

  final int shakeCountResetTime;

  final int minShakeCount;

  int shakeCount = 0;

  int lastShakeTimestamp = DateTime.now().millisecondsSinceEpoch;

  StreamSubscription? streamSubscription;

  ShakeDetector({
    required this.onPhoneShake,
    this.shakeThresholdGravity = 1.25,
    this.minTimeBetweenShakes = 160,
    this.shakeCountResetTime = 1500,
    this.minShakeCount = 2,
  });

  /// Starts listening to accerelometer events
  void startListening() {
    streamSubscription = accelerometerEventStream().listen((event) {
      var gX = event.x / 9.81;
      var gY = event.y / 9.81;
      var gZ = event.z / 9.81;

      // gForce will be close to 1 when there is no movement.
      var gForce = sqrt(gX * gX + gY * gY + gZ * gZ);
      if (gForce > shakeThresholdGravity) {
        var now = DateTime.now().millisecondsSinceEpoch;
        // ignore shake events too close to each other
        if (lastShakeTimestamp + minTimeBetweenShakes > now) {
          return;
        }

        // reset the shake count after 1.5 seconds of no shakes
        if (lastShakeTimestamp + shakeCountResetTime < now) {
          shakeCount = 0;
        }

        lastShakeTimestamp = now;
        if (++shakeCount >= minShakeCount) {
          shakeCount = 0;
          onPhoneShake();
        }
      }
    });
  }

  /// Stops listening to accelerometer events
  void stopListening() {
    final sub = streamSubscription;
    if (sub != null) {
      sub.cancel();
    }
  }
}
