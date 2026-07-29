import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class PedometerService {
  static final PedometerService _instance = PedometerService._internal();
  factory PedometerService() => _instance;
  PedometerService._internal();

  StreamSubscription<StepCount>? _stepSubscription;
  Function(int steps)? _onStepCount;

  void init({required Function(int steps) onStepCount}) async {
    _onStepCount = onStepCount;

    try {
      if (await Permission.activityRecognition.request().isGranted) {
        _stepSubscription?.cancel();
        _stepSubscription = Pedometer.stepCountStream.listen(
          (StepCount event) {
            if (_onStepCount != null && event.steps > 0) {
              _onStepCount!(event.steps);
            }
          },
          onError: (_) {},
          cancelOnError: false,
        );
      }
    } catch (_) {}
  }

  void stop() {
    _stepSubscription?.cancel();
    _onStepCount = null;
  }
}
