import 'package:flutter/foundation.dart';

/// مسار ملف VCF جاي من برّه التطبيق (فتح/مشاركة على أندرويد، أو دبل كليك على ويندوز)
class IncomingFile {
  static final ValueNotifier<String?> path = ValueNotifier<String?>(null);
}
