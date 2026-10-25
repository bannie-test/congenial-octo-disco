import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Hiệu ứng âm thanh: giọt nước khi hoàn thành một thói quen, chuông vui
/// khi đạt mục tiêu ngày, nốt trầm khi lỡ mục tiêu.
enum Sfx { drop, success, missed }

abstract class SoundService {
  Future<void> play(Sfx sfx);
}

/// Không phát gì (dùng cho kiểm thử).
class SilentSoundService implements SoundService {
  final played = <Sfx>[];

  @override
  Future<void> play(Sfx sfx) async => played.add(sfx);
}

class AssetSoundService implements SoundService {
  final _players = <Sfx, AudioPlayer>{};

  @override
  Future<void> play(Sfx sfx) async {
    try {
      final player = _players.putIfAbsent(sfx, () => AudioPlayer()..setReleaseMode(ReleaseMode.stop));
      await player.stop();
      await player.play(AssetSource('sounds/${sfx.name}.wav'), mode: PlayerMode.lowLatency, volume: 0.8);
    } catch (e) {
      debugPrint('Không phát được âm thanh: $e');
    }
  }
}
