import 'dart:convert';

import 'package:http/http.dart' as http;

class City {
  const City(this.name, this.lat, this.lon);
  final String name;
  final double lat;
  final double lon;
}

const cities = <City>[
  City('Hà Nội', 21.03, 105.85),
  City('TP. Hồ Chí Minh', 10.78, 106.70),
  City('Đà Nẵng', 16.05, 108.20),
  City('Hải Phòng', 20.86, 106.68),
  City('Cần Thơ', 10.03, 105.78),
  City('Huế', 16.46, 107.59),
  City('Nha Trang', 12.24, 109.19),
  City('Đà Lạt', 11.94, 108.44),
  City('Quy Nhơn', 13.78, 109.22),
  City('Vũng Tàu', 10.35, 107.08),
];

/// Dự báo của một ngày.
class DayForecast {
  const DayForecast({
    required this.day,
    required this.code,
    required this.min,
    required this.max,
    required this.rain,
  });

  /// Khóa ngày dạng `yyyy-mm-dd`.
  final String day;
  final int code;
  final double min;
  final double max;

  /// Khả năng mưa (%).
  final int rain;

  /// "Có mưa rào, 24–31°C, khả năng mưa 70%"
  String get summary => '${weatherLabel(code)}, ${min.round()}–${max.round()}°C, khả năng mưa $rain%';

  Map<String, dynamic> toJson() => {'day': day, 'code': code, 'min': min, 'max': max, 'rain': rain};

  factory DayForecast.fromJson(Map<String, dynamic> j) => DayForecast(
    day: j['day'] as String,
    code: (j['code'] as num).toInt(),
    min: (j['min'] as num).toDouble(),
    max: (j['max'] as num).toDouble(),
    rain: (j['rain'] as num).toInt(),
  );
}

class Weather {
  const Weather({
    required this.temp,
    required this.humidity,
    required this.code,
    required this.fetchedAt,
    this.days = const [],
  });

  final double temp;
  final int humidity;
  final int code;
  final DateTime fetchedAt;
  final List<DayForecast> days;

  DayForecast? forecastFor(String day) => days.where((d) => d.day == day).firstOrNull;

  bool get rainy => isRainy(code);

  Map<String, dynamic> toJson() => {
    'temp': temp,
    'humidity': humidity,
    'code': code,
    'fetchedAt': fetchedAt.toIso8601String(),
    'days': days.map((d) => d.toJson()).toList(),
  };

  factory Weather.fromJson(Map<String, dynamic> j) => Weather(
    temp: (j['temp'] as num).toDouble(),
    humidity: (j['humidity'] as num).toInt(),
    code: (j['code'] as num).toInt(),
    fetchedAt: DateTime.parse(j['fetchedAt'] as String),
    days: ((j['days'] as List?) ?? const [])
        .map((e) => DayForecast.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Mã thời tiết WMO -> mô tả tiếng Việt.
String weatherLabel(int code) => switch (code) {
  0 => 'Trời quang',
  1 || 2 => 'Có mây nhẹ',
  3 => 'Nhiều mây',
  45 || 48 => 'Có sương mù',
  >= 51 && <= 57 => 'Mưa phùn',
  >= 61 && <= 67 => 'Có mưa',
  >= 71 && <= 77 => 'Có tuyết',
  >= 80 && <= 82 => 'Có mưa rào',
  >= 95 => 'Có dông',
  _ => 'Thời tiết ổn định',
};

String weatherEmoji(int code, {bool night = false}) => switch (code) {
  0 => night ? '🌙' : '☀️',
  1 || 2 => night ? '☁️' : '🌤️',
  3 => '☁️',
  45 || 48 => '🌫️',
  >= 51 && <= 67 => '🌧️',
  >= 71 && <= 77 => '❄️',
  >= 80 && <= 82 => '🌦️',
  >= 95 => '⛈️',
  _ => '🌤️',
};

bool isRainy(int code) => (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95;

abstract class WeatherService {
  Future<Weather?> fetch(City city);
}

/// Không gọi mạng (dùng cho kiểm thử).
class NoWeatherService implements WeatherService {
  @override
  Future<Weather?> fetch(City city) async => null;
}

/// Dữ liệu từ Open-Meteo: miễn phí, không cần khoá API.
class OpenMeteoService implements WeatherService {
  @override
  Future<Weather?> fetch(City city) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${city.lat}',
      'longitude': '${city.lon}',
      'current': 'temperature_2m,relative_humidity_2m,weather_code',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'timezone': 'auto',
      'forecast_days': '3',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final current = j['current'] as Map<String, dynamic>;
    final daily = j['daily'] as Map<String, dynamic>;
    final dates = (daily['time'] as List).cast<String>();
    num at(String key, int i) => ((daily[key] as List)[i] as num?) ?? 0;
    return Weather(
      temp: (current['temperature_2m'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).toInt(),
      code: (current['weather_code'] as num).toInt(),
      fetchedAt: DateTime.now(),
      days: [
        for (var i = 0; i < dates.length; i++)
          DayForecast(
            day: dates[i],
            code: at('weather_code', i).toInt(),
            min: at('temperature_2m_min', i).toDouble(),
            max: at('temperature_2m_max', i).toDouble(),
            rain: at('precipitation_probability_max', i).toInt(),
          ),
      ],
    );
  }
}
