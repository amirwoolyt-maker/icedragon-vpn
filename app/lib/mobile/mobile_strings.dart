import 'package:flutter/widgets.dart';

/// Localized UI strings for the mobile-specific features (Dark Glass home,
/// live speed chart, favorites, smart connection doctor, LAN sharing, and
/// Android system Kill Switch) while keeping generated AppLocalizations files
/// intact.
class MobileStrings {
  const MobileStrings._(this.lang);

  final String lang;

  static MobileStrings of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return MobileStrings._(code);
  }

  bool get isFa => lang == 'fa';
  bool get isAr => lang == 'ar';

  String get quickAuto => switch (lang) {
    'fa' => 'خودکار',
    'ar' => 'تلقائي',
    _ => 'Auto',
  };

  String get quickFastest => switch (lang) {
    'fa' => 'سریع‌ترین',
    'ar' => 'الأسرع',
    _ => 'Fastest',
  };

  String get allServersShort => switch (lang) {
    'fa' => 'همه سرورها',
    'ar' => 'كل الخوادم',
    _ => 'All servers',
  };

  String get quickCountriesTitle => switch (lang) {
    'fa' => 'انتخاب سریع کشور',
    'ar' => 'اختيار سريع للدولة',
    _ => 'Quick locations',
  };

  String get favoriteLocations => switch (lang) {
    'fa' => 'کشورهای محبوب',
    'ar' => 'المواقع المفضلة',
    _ => 'Favorites',
  };

  String get pinFavorite => switch (lang) {
    'fa' => 'افزودن به محبوب‌ها',
    'ar' => 'إضافة إلى المفضلة',
    _ => 'Pin to favorites',
  };

  String get unpinFavorite => switch (lang) {
    'fa' => 'حذف از محبوب‌ها',
    'ar' => 'إزالة من المفضلة',
    _ => 'Remove favorite',
  };

  String get connectFastestOneTap => switch (lang) {
    'fa' => 'تست پینگ و اتصال به سریع‌ترین',
    'ar' => 'فحص البنق والاتصال بالأسرع',
    _ => 'Ping & connect fastest',
  };

  String get connectingFastest => switch (lang) {
    'fa' => 'در حال یافتن سریع‌ترین کشور…',
    'ar' => 'جارٍ البحث عن أسرع دولة…',
    _ => 'Finding the fastest location…',
  };

  String connectedToFastest(String country, int ms) => switch (lang) {
    'fa' => 'متصل به $country ($ms میلی‌ثانیه)',
    'ar' => 'متصل بـ $country ($ms مللي ثانية)',
    _ => 'Connected to $country ($ms ms)',
  };

  String get liveSpeed => switch (lang) {
    'fa' => 'سرعت زنده',
    'ar' => 'السرعة المباشرة',
    _ => 'Live speed',
  };

  String get downloadLabel => switch (lang) {
    'fa' => 'دانلود',
    'ar' => 'التنزيل',
    _ => 'Download',
  };

  String get uploadLabel => switch (lang) {
    'fa' => 'آپلود',
    'ar' => 'الرفع',
    _ => 'Upload',
  };

  String get sessionData => switch (lang) {
    'fa' => 'حجم نشست',
    'ar' => 'بيانات الجلسة',
    _ => 'Session',
  };

  String get connectedFor => switch (lang) {
    'fa' => 'مدت اتصال',
    'ar' => 'مدة الاتصال',
    _ => 'Duration',
  };

  String get smartDoctor => switch (lang) {
    'fa' => 'پزشک اتصال هوشمند',
    'ar' => 'المصلح الذكي للاتصال',
    _ => 'Smart Connection Doctor',
  };

  String get smartDoctorShort => switch (lang) {
    'fa' => 'عیب‌یابی هوشمند',
    'ar' => 'تشخيص ذكي',
    _ => 'Auto-Fix',
  };

  String get autoFixAndConnect => switch (lang) {
    'fa' => 'تنظیم خودکار بهترین مسیر و اتصال',
    'ar' => 'إصلاح تلقائي والاتصال',
    _ => 'Auto-Fix & Connect',
  };

  String get smartDoctorIntro => switch (lang) {
    'fa' =>
        'پزشک اتصال به‌صورت خودکار DNS، رله، TLS Fragment و پروتکل‌های H2/H3/H1 را برای شبکه فعلی آزمایش می‌کند تا بهترین مسیر وصل به Mozilla پیدا شود.',
    'ar' =>
        'يقوم المصلح الذكي باختبار DNS والترحيل وTLS Fragment وبروتوكولات H2/H3/H1 تلقائياً لإيجاد أفضل مسار لـ Mozilla.',
    _ =>
        'Automatically probes DoH DNS, relays, TLS Fragment modes, and H2/H3/H1 transports to find a working path for your current network.',
  };

  String get doctorStepDns => switch (lang) {
    'fa' => 'بررسی سلامت DNS و فیلتر نبودن DoH',
    'ar' => 'فحص سلامة DNS وعدم حجبه',
    _ => 'Checking encrypted DNS (DoH) reachability',
  };

  String get doctorStepRelay => switch (lang) {
    'fa' => 'بررسی رله شخصی / استخر رله Mozilla',
    'ar' => 'فحص خادم الترحيل (Relay)',
    _ => 'Checking API relay recovery',
  };

  String doctorTryingProfile(String label) => switch (lang) {
    'fa' => 'تست پروفایل: $label',
    'ar' => 'اختبار الإعداد: $label',
    _ => 'Testing profile: $label',
  };

  String get doctorStart => switch (lang) {
    'fa' => 'شروع عیب‌یابی و تنظیم خودکار',
    'ar' => 'بدء الفحص والإصلاح التلقائي',
    _ => 'Start Smart Auto-Fix',
  };

  String get doctorRunning => switch (lang) {
    'fa' => 'در حال آزمایش مسیرهای اتصال…',
    'ar' => 'جارٍ اختبار مسارات الاتصال…',
    _ => 'Testing connection profiles…',
  };

  String doctorSuccess(String profile, int ms) => switch (lang) {
    'fa' => 'مسیر سالم پیدا شد و ذخیره گردید: $profile ($ms ms)',
    'ar' => 'تم العثور على مسار ناجح وحفظه: $profile ($ms ms)',
    _ => 'Working profile found and saved: $profile ($ms ms)',
  };

  String get doctorNoProfileWorked => switch (lang) {
    'fa' =>
        'هیچ‌کدام از پروفایل‌های مستقیم روی این شبکه پاسخ نداد. تنظیمات قبلی بازگردانده شد. اگر موزیلا یا کلودفلر کاملاً بسته است، یک رله شخصی یا پروکسی بالادستی (Upstream Proxy) تنظیم کنید.',
    'ar' =>
        'لم يستجب أي مسار مباشر على هذه الشبكة، وتمت استعادة الإعدادات السابقة.',
    _ =>
        'No built-in profile succeeded on this network. Previous settings were restored. Consider setting a personal API relay or upstream SOCKS5 proxy.',
  };

  String get doctorNeedAccount => switch (lang) {
    'fa' => 'ابتدا حداقل یک حساب فایرفاکس اضافه کنید تا تست اتصال انجام شود.',
    'ar' => 'أضف حساب Firefox أولاً لإجراء فحص الاتصال.',
    _ => 'Add at least one Firefox Account first before running Auto-Fix.',
  };

  String get doctorRestore => switch (lang) {
    'fa' => 'بازگردانی تنظیمات قبلی',
    'ar' => 'استعادة الإعدادات السابقة',
    _ => 'Restore previous settings',
  };

  String get doctorDnsCleaned => switch (lang) {
    'fa' => 'فیلترینگ DNS شبکه شناسایی شد؛ DoH خودکار فعال گردید.',
    'ar' => 'تم اكتشاف تصفية DNS وتفعيل DoH التلقائي.',
    _ => 'Network DNS filtering detected; enabled Auto DoH.',
  };

  String get killSwitchTitle => switch (lang) {
    'fa' => 'Kill Switch سیستم اندروید',
    'ar' => 'مفتاح الإيقاف Kill Switch',
    _ => 'System Kill Switch (Android VPN)',
  };

  String get killSwitchSubtitle => switch (lang) {
    'fa' =>
        'باز کردن تنظیمات VPN اندروید برای فعال‌سازی Always-on و «مسدودسازی اتصالات بدون VPN».',
    'ar' =>
        'افتح إعدادات VPN في أندرويد لتفعيل Always-on وحظر الاتصال بدون VPN.',
    _ =>
        'Opens Android VPN settings to enable Always-on VPN & Block connections without VPN.',
  };

  String get hotspotShareTitle => switch (lang) {
    'fa' => 'اشتراک‌گذاری پروکسی روی Wi-Fi / هات‌اسپات',
    'ar' => 'مشاركة الوكيل عبر Wi-Fi / نقطة الاتصال',
    _ => 'Share VPN proxy over Wi-Fi / Hotspot',
  };

  String hotspotShareAddress(String addr) => switch (lang) {
    'fa' => 'سایر دستگاه‌های هم‌شبکه روی آدرس $addr متصل شوند.',
    'ar' => 'يمكن للأجهزة الأخرى الاتصال عبر $addr',
    _ => 'Other devices on the same network can use $addr.',
  };

  String get hotspotShareNoIp => switch (lang) {
    'fa' => 'Wi-Fi یا هات‌اسپات برای دریافت آدرس محلی پیدا نشد.',
    'ar' => 'لم يتم العثور على عنوان شبكة محلية.',
    _ => 'No active Wi-Fi or local hotspot IP detected.',
  };

  String get showSpeedChartLabel => switch (lang) {
    'fa' => 'نمودار سرعت زنده در صفحه خانه',
    'ar' => 'مخطط السرعة المباشر في الرئيسية',
    _ => 'Live speed chart on Home',
  };

  String get dnsProviderHint => switch (lang) {
    'fa' => 'این DNS فقط برای نام‌هایی است که خود هستهٔ VPN جست‌وجو می‌کند؛ DNS دستگاه تغییر نمی‌کند.',
    'ar' => 'يُستخدم DNS هذا لأسماء نطاقات نواة VPN فقط؛ لا يتغير DNS الجهاز.',
    _ => 'These resolvers are used for names looked up by the VPN core only; device DNS is unchanged.',
  };

  String get modeDns => switch (lang) {
    'fa' => 'حالت DNS',
    'ar' => 'وضع DNS',
    _ => 'DNS Mode',
  };

  String get modeDnsHint => switch (lang) {
    'fa' => 'DNS انتخاب‌شده فقط برای جست‌وجوهای هستهٔ VPN است؛ DNS دستگاه تغییر نمی‌کند و تونل VPN روشن نمی‌شود.',
    'ar' => 'يُستخدم DNS المختار لاستعلامات نواة VPN فقط؛ لا يتغير DNS الجهاز ولا يبدأ نفق VPN.',
    _ => 'Selected DNS is used only for VPN-core lookups; device DNS is unchanged and the VPN tunnel stays off.',
  };

  String get dnsQuickSelect => switch (lang) {
    'fa' => 'انتخاب DNS',
    'ar' => 'اختيار DNS',
    _ => 'Choose DNS provider',
  };

  String dnsProviderPing(int ms) => switch (lang) {
    'fa' => 'پینگ DNS: $ms میلی‌ثانیه',
    'ar' => 'زمن استجابة DNS: $ms مللي ثانية',
    _ => 'DNS ping: $ms ms',
  };

  String get dnsModeEnabled => switch (lang) {
    'fa' => 'حالت DNS روشن است',
    'ar' => 'وضع DNS قيد التشغيل',
    _ => 'DNS mode is on',
  };

  String get dnsAddProvider => switch (lang) {
    'fa' => 'افزودن DNS سفارشی',
    'ar' => 'إضافة DNS مخصص',
    _ => 'Add custom provider',
  };

  String get dnsEditProvider => switch (lang) {
    'fa' => 'ویرایش ارائه‌دهنده',
    'ar' => 'تعديل المزوّد',
    _ => 'Edit provider',
  };

  String get dnsProviderName => switch (lang) {
    'fa' => 'نام',
    'ar' => 'الاسم',
    _ => 'Name',
  };

  String get dnsProviderNameRequired => switch (lang) {
    'fa' => 'نام را وارد کنید',
    'ar' => 'أدخل الاسم',
    _ => 'Enter a name',
  };

  String get dnsProviderServers => switch (lang) {
    'fa' => 'آدرس سرورها',
    'ar' => 'عناوين الخوادم',
    _ => 'Server addresses',
  };

  String get dnsProviderServersHint => switch (lang) {
    'fa' => 'هر آدرس در یک خط؛ IP یا URL رمزگذاری‌شده',
    'ar' => 'عنوان واحد في كل سطر؛ IP أو URL مشفر',
    _ => 'One per line; IP address or encrypted DNS URL',
  };

  String get dnsProviderServersRequired => switch (lang) {
    'fa' => 'حداقل یک سرور وارد کنید',
    'ar' => 'أدخل خادماً واحداً على الأقل',
    _ => 'Enter at least one server',
  };

  String get dnsProviderServerInvalid => switch (lang) {
    'fa' => 'آدرس سرور معتبر نیست',
    'ar' => 'عنوان الخادم غير صالح',
    _ => 'Invalid server address',
  };

  String get dnsUseProvider => switch (lang) {
    'fa' => 'استفاده',
    'ar' => 'استخدام',
    _ => 'Use',
  };

  String get dnsBenchmark => switch (lang) {
    'fa' => 'تست',
    'ar' => 'اختبار',
    _ => 'Benchmark',
  };

  String dnsBenchmarkResult(int ms) => switch (lang) {
    'fa' => 'میانگین زمان پاسخ هسته: $ms میلی‌ثانیه',
    'ar' => 'متوسط زمن استجابة النواة: $ms مللي ثانية',
    _ => 'Average VPN-core lookup: $ms ms',
  };

  String get dnsBenchmarkFailed => switch (lang) {
    'fa' => 'هیچ نامی با این DNS پاسخ نداد.',
    'ar' => 'لم تُحل أي أسماء باستخدام DNS هذا.',
    _ => 'No test names resolved through this provider.',
  };

  String get quickToolsTitle => switch (lang) {
    'fa' => 'ابزارهای سریع',
    'ar' => 'أدوات سريعة',
    _ => 'Quick tools',
  };

  String moreAccountsAvailable(int count) => switch (lang) {
    'fa' => '$count حساب آمادهٔ دیگر',
    'ar' => '$count حسابات جاهزة أخرى',
    _ => '$count more ready',
  };

  String get perAppSplit => switch (lang) {
    'fa' => 'انتخاب برنامه‌ها',
    'ar' => 'تحديد التطبيقات',
    _ => 'App routing',
  };

  String get cleanOpenSourceNote => switch (lang) {
    'fa' => 'متن‌باز و امن · هسته رسمی موزیلا بدون کد ردیابی',
    'ar' => 'مفتوح المصدر وآمن · بدون تتبع',
    _ => 'Clean & Auditable · No tracking or hidden binaries',
  };
}
