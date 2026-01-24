import 'package:flutter/material.dart';

class TimerSettingsScreen extends StatelessWidget {
  const TimerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('플레이 시간 설정'),
      ),
      body: const Center(
        child: Text('타이머 간격 설정 화면 - 준비 중'),
      ),
    );
  }
}
