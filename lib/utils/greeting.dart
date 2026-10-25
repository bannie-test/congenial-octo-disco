import '../services/weather.dart';

/// Lời chào ngắn theo giờ, dùng ở đầu màn hình chính.
String greetingTitle(DateTime t) => switch (t.hour) {
  >= 5 && < 11 => 'Chào buổi sáng ☀️',
  >= 11 && < 14 => 'Buổi trưa vui vẻ 🌤️',
  >= 14 && < 18 => 'Chào buổi chiều 🌿',
  >= 18 && < 22 => 'Buổi tối an lành 🌙',
  _ => 'Khuya rồi, ngủ sớm nhé 😴',
};

/// Những câu Mầm nói khi được chạm vào: theo giờ, thời tiết, mục tiêu và sức sống.
List<String> plantLines({
  required DateTime now,
  required Weather? weather,
  required double vitality,
  required int done,
  required int goal,
}) {
  final h = now.hour;
  final lines = <String>[
    switch (h) {
      >= 5 && < 11 => 'Chào buổi sáng! Mình vừa thức dậy cùng ánh nắng ☀️',
      >= 11 && < 14 => 'Trưa rồi, nghỉ ngơi một chút cho khỏe nha 🍃',
      >= 14 && < 18 => 'Buổi chiều rồi, đi bộ một vòng với mình không?',
      >= 18 && < 22 => 'Tối rồi, kể mình nghe hôm nay của bạn thế nào?',
      _ => 'Khuya rồi đó, ngủ sớm để mai cả hai cùng tươi tắn nhé 😴',
    },
  ];
  if (weather != null) {
    final t = weather.temp.round();
    if (weather.rainy) {
      lines.add('Ngoài trời đang mưa, ra ngoài nhớ mang ô nha ☔');
    } else if (t >= 33) {
      lines.add('Trời nóng $t°C, mình khát lắm, bạn cũng uống nước nha 💧');
    } else if (t <= 18) {
      lines.add('Trời se lạnh $t°C, giữ ấm nhé 🧣');
    } else {
      lines.add('Trời $t°C dễ chịu ghê, hợp để vận động lắm!');
    }
    if (weather.humidity >= 85) lines.add('Độ ẩm ${weather.humidity}%, không khí hơi oi đó.');
  }
  if (goal > 0) {
    lines.add(
      done >= goal
          ? 'Hôm nay bạn đạt mục tiêu rồi, mình vui quá! 🌸'
          : 'Còn ${goal - done} thói quen nữa là đạt mục tiêu hôm nay, cố lên!',
    );
  }
  if (vitality < 0.5) lines.add('Mình hơi héo… tưới cho mình một giọt nhé 🥺');
  lines.addAll(['Hihi, nhột quá!', 'Cảm ơn bạn đã ghé thăm mình 💚']);
  return lines;
}
