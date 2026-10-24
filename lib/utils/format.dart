/// 120000 -> "120.000đ"
String formatVnd(int amount) {
  final digits = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}$bufđ';
}

/// Số phút tính từ 0 giờ -> "08:05".
String formatHm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// Khoảng thời gian ngắn gọn: "3 ngày", "5 giờ", "12 phút".
String formatSpan(Duration d) {
  if (d.inDays > 0) return '${d.inDays} ngày';
  if (d.inHours > 0) return '${d.inHours} giờ';
  return '${d.inMinutes} phút';
}

/// Thời điểm tương đối kiểu "5 phút trước", "Hôm qua 21:00", "12/10".
String formatAgo(DateTime at, DateTime now) {
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final time = formatHm(at.hour * 60 + at.minute);
  if (day == today) return '${diff.inHours} giờ trước';
  if (today.difference(day).inDays == 1) return 'Hôm qua $time';
  return '${at.day}/${at.month}';
}

const weekdayNames = ['Thứ hai', 'Thứ ba', 'Thứ tư', 'Thứ năm', 'Thứ sáu', 'Thứ bảy', 'Chủ nhật'];
const weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

/// "Thứ bảy, 24/10"
String formatDate(DateTime d) => '${weekdayNames[d.weekday - 1]}, ${d.day}/${d.month}';
