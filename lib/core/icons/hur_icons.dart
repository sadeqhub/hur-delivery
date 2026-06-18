/// Central registry for the Hur icon set.
///
/// Design spec (all icons in `assets/icons/`):
/// - 24×24 viewBox, 1.75px stroke, round caps/joins
/// - Monochrome `#000000` paths — tint via [HurIcon] / [ColorFilter.mode]
/// - Minimal geometric forms aligned to the teal delivery brand
abstract final class HurIcons {
  static const String _root = 'assets/icons';

  // Brand & roles
  static const String bird = '$_root/bird.svg';
  static const String merchant = '$_root/merchant.svg';
  static const String driver = '$_root/driver.svg';

  // Navigation & shell
  static const String home = '$_root/home.svg';
  static const String menu = '$_root/menu.svg';
  static const String orders = '$_root/orders.svg';
  static const String wallet = '$_root/wallet.svg';
  static const String profile = '$_root/profile.svg';
  static const String settings = '$_root/settings.svg';
  static const String notifications = '$_root/notifications.svg';
  static const String support = '$_root/support.svg';

  // Actions & content
  static const String analytics = '$_root/analytics.svg';
  static const String edit = '$_root/edit.svg';
  static const String mapPin = '$_root/map-pin.svg';
  static const String phone = '$_root/phone.svg';
  static const String package = '$_root/package.svg';
  static const String navigation = '$_root/navigation.svg';
  static const String search = '$_root/search.svg';
  static const String add = '$_root/add.svg';
  static const String minus = '$_root/minus.svg';
  static const String mic = '$_root/mic.svg';
  static const String info = '$_root/info.svg';
  static const String check = '$_root/check.svg';
  static const String calendar = '$_root/calendar.svg';
  static const String chat = '$_root/chat.svg';
  static const String refresh = '$_root/refresh.svg';
  static const String payment = '$_root/payment.svg';
  static const String camera = '$_root/camera.svg';
  static const String close = '$_root/close.svg';
  static const String warning = '$_root/warning.svg';
  static const String clock = '$_root/clock.svg';
  static const String chevronLeft = '$_root/chevron-left.svg';
  static const String chevronRight = '$_root/chevron-right.svg';
  static const String chevronDown = '$_root/chevron-down.svg';
  static const String arrowForward = '$_root/arrow-forward.svg';
  static const String sun = '$_root/sun.svg';
  static const String moon = '$_root/moon.svg';
  static const String globe = '$_root/globe.svg';
  static const String wifiOff = '$_root/wifi-off.svg';
  static const String percent = '$_root/percent.svg';

  // Legal & account
  static const String shield = '$_root/shield.svg';
  static const String document = '$_root/document.svg';
  static const String logout = '$_root/logout.svg';
  static const String help = '$_root/help.svg';

  /// All Hur SVG assets — use for precaching at startup.
  static const List<String> all = [
    bird,
    merchant,
    driver,
    home,
    menu,
    orders,
    wallet,
    profile,
    settings,
    notifications,
    support,
    analytics,
    edit,
    mapPin,
    phone,
    package,
    navigation,
    search,
    add,
    minus,
    mic,
    info,
    check,
    calendar,
    chat,
    refresh,
    payment,
    camera,
    close,
    warning,
    clock,
    chevronLeft,
    chevronRight,
    chevronDown,
    arrowForward,
    sun,
    moon,
    globe,
    wifiOff,
    percent,
    shield,
    document,
    logout,
    help,
  ];
}

/// Typed icon identifiers — prefer these over raw asset path strings.
enum HurIconKind {
  bird,
  merchant,
  driver,
  home,
  menu,
  orders,
  wallet,
  profile,
  settings,
  notifications,
  support,
  analytics,
  edit,
  mapPin,
  phone,
  package,
  navigation,
  search,
  add,
  minus,
  mic,
  info,
  check,
  calendar,
  chat,
  refresh,
  payment,
  camera,
  close,
  warning,
  clock,
  chevronLeft,
  chevronRight,
  chevronDown,
  arrowForward,
  sun,
  moon,
  globe,
  wifiOff,
  percent,
  shield,
  document,
  logout,
  help,
}

extension HurIconKindX on HurIconKind {
  String get assetPath => switch (this) {
        HurIconKind.bird => HurIcons.bird,
        HurIconKind.merchant => HurIcons.merchant,
        HurIconKind.driver => HurIcons.driver,
        HurIconKind.home => HurIcons.home,
        HurIconKind.menu => HurIcons.menu,
        HurIconKind.orders => HurIcons.orders,
        HurIconKind.wallet => HurIcons.wallet,
        HurIconKind.profile => HurIcons.profile,
        HurIconKind.settings => HurIcons.settings,
        HurIconKind.notifications => HurIcons.notifications,
        HurIconKind.support => HurIcons.support,
        HurIconKind.analytics => HurIcons.analytics,
        HurIconKind.edit => HurIcons.edit,
        HurIconKind.mapPin => HurIcons.mapPin,
        HurIconKind.phone => HurIcons.phone,
        HurIconKind.package => HurIcons.package,
        HurIconKind.navigation => HurIcons.navigation,
        HurIconKind.search => HurIcons.search,
        HurIconKind.add => HurIcons.add,
        HurIconKind.minus => HurIcons.minus,
        HurIconKind.mic => HurIcons.mic,
        HurIconKind.info => HurIcons.info,
        HurIconKind.check => HurIcons.check,
        HurIconKind.calendar => HurIcons.calendar,
        HurIconKind.chat => HurIcons.chat,
        HurIconKind.refresh => HurIcons.refresh,
        HurIconKind.payment => HurIcons.payment,
        HurIconKind.camera => HurIcons.camera,
        HurIconKind.close => HurIcons.close,
        HurIconKind.warning => HurIcons.warning,
        HurIconKind.clock => HurIcons.clock,
        HurIconKind.chevronLeft => HurIcons.chevronLeft,
        HurIconKind.chevronRight => HurIcons.chevronRight,
        HurIconKind.chevronDown => HurIcons.chevronDown,
        HurIconKind.arrowForward => HurIcons.arrowForward,
        HurIconKind.sun => HurIcons.sun,
        HurIconKind.moon => HurIcons.moon,
        HurIconKind.globe => HurIcons.globe,
        HurIconKind.wifiOff => HurIcons.wifiOff,
        HurIconKind.percent => HurIcons.percent,
        HurIconKind.shield => HurIcons.shield,
        HurIconKind.document => HurIcons.document,
        HurIconKind.logout => HurIcons.logout,
        HurIconKind.help => HurIcons.help,
      };
}

/// Standard icon sizes aligned to the 4pt grid.
enum HurIconSize {
  xs(16),
  sm(20),
  md(24),
  lg(32),
  xl(40),
  hero(48);

  const HurIconSize(this.pixels);
  final double pixels;
}

/// Semantic tints for icons on light/dark surfaces and brand chrome.
enum HurIconTone {
  primary,
  onPrimary,
  muted,
  destructive,
}
