class Neighborhood {
  final String name;
  final double latitude;
  final double longitude;

  Neighborhood({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class NeighborhoodsData {
  static final List<Neighborhood> neighborhoods = [
    Neighborhood(name: 'البراكية', latitude: 32.00945053255765, longitude: 44.41963913733821),
    Neighborhood(name: 'الجديدة', latitude: 31.988596767158885, longitude: 44.326891103621406),
    Neighborhood(name: 'الجمهورية', latitude: 32.03325745684228, longitude: 44.40054412866054),
    Neighborhood(name: 'السفير', latitude: 32.030483238931225, longitude: 44.40641963813284),
    Neighborhood(name: 'السهلة', latitude: 32.03989462609451, longitude: 44.378233723989055),
    Neighborhood(name: 'الكوفة حي الشرطة', latitude: 32.02406631573205, longitude: 44.38199946653831),
    Neighborhood(name: 'الكوفة حي العسكري', latitude: 32.03484214753685, longitude: 44.38145924609706),
    Neighborhood(name: 'الكوفة حي المعلمين', latitude: 32.031121436909714, longitude: 44.39171145992998),
    Neighborhood(name: 'جامعة الكوفة', latitude: 32.01862643282866, longitude: 44.37702681179998),
    Neighborhood(name: 'حي ابو خالد', latitude: 31.996544281582462, longitude: 44.33683505069235),
    Neighborhood(name: 'حي ابو طالب', latitude: 32.025548805151125, longitude: 44.314601451938344),
    Neighborhood(name: 'حي الاسكان', latitude: 32.005873246619764, longitude: 44.351395169982446),
    Neighborhood(name: 'حي الاشتراكي', latitude: 32.002552885161634, longitude: 44.35368671726379),
    Neighborhood(name: 'حي الاطباء', latitude: 32.02031456425115, longitude: 44.328579644709244),
    Neighborhood(name: 'حي الامام المهدي', latitude: 31.988623340357005, longitude: 44.34301031379616),
    Neighborhood(name: 'حي الامير', latitude: 32.006866220904634, longitude: 44.365070755049466),
    Neighborhood(name: 'حي الانصار', latitude: 31.98750286672427, longitude: 44.358527429735965),
    Neighborhood(name: 'حي الجامعة', latitude: 32.03500819380669, longitude: 44.35241700977221),
    Neighborhood(name: 'حي الجزيرة', latitude: 32.045700052904415, longitude: 44.33382422674479),
    Neighborhood(name: 'حي الجمعية', latitude: 32.04055211727648, longitude: 44.326577223808215),
    Neighborhood(name: 'حي الحرفيين', latitude: 31.991522497645853, longitude: 44.36870907337595),
    Neighborhood(name: 'حي الحسين', latitude: 32.009269314458365, longitude: 44.33405568951555),
    Neighborhood(name: 'حي الحنانة', latitude: 32.005098019966525, longitude: 44.33383990544202),
    Neighborhood(name: 'حي الرحمة', latitude: 32.01852404889218, longitude: 44.317189873491806),
    Neighborhood(name: 'حي الزهراء', latitude: 31.99913931599307, longitude: 44.36480349357464),
    Neighborhood(name: 'حي السعد', latitude: 32.001939837707674, longitude: 44.34195818316487),
    Neighborhood(name: 'حي السلام', latitude: 32.03063341531937, longitude: 44.34191558841886),
    Neighborhood(name: 'حي السواق', latitude: 31.996239460692895, longitude: 44.3566888915987),
    Neighborhood(name: 'حي الشرطة', latitude: 31.98195467289134, longitude: 44.329922441761155),
    Neighborhood(name: 'حي الشعراء', latitude: 32.015286600917975, longitude: 44.334957648580406),
    Neighborhood(name: 'حي الشهداء', latitude: 32.04876110800057, longitude: 44.34690650567454),
    Neighborhood(name: 'حي الصحة', latitude: 32.01054946938756, longitude: 44.34299822147059),
    Neighborhood(name: 'حي الصناعي', latitude: 32.016806959872504, longitude: 44.37797244115495),
    Neighborhood(name: 'حي العدالة', latitude: 32.022208009344794, longitude: 44.36066808441254),
    Neighborhood(name: 'حي العروبة', latitude: 32.045700052904415, longitude: 44.33382422674479),
    Neighborhood(name: 'حي العسكري', latitude: 32.0660260536408, longitude: 44.337680220489936),
    Neighborhood(name: 'حي العلماء', latitude: 32.014729862177376, longitude: 44.330281366921625),
    Neighborhood(name: 'حي الغدير', latitude: 32.01671945886399, longitude: 44.34596587742843),
    Neighborhood(name: 'حي الغري الاول', latitude: 32.01851574622202, longitude: 44.328720744221336),
    Neighborhood(name: 'حي الغري الثاني', latitude: 32.02349243873796, longitude: 44.33474492677049),
    Neighborhood(name: 'حي الفرات', latitude: 32.01905614074013, longitude: 44.35221769346194),
    Neighborhood(name: 'حي القادسية', latitude: 32.001952520811024, longitude: 44.37330085976419),
    Neighborhood(name: 'حي القدس', latitude: 31.979652543272294, longitude: 44.35200693983141),
    Neighborhood(name: 'حي الكرامة', latitude: 32.0141041009887, longitude: 44.34109272445229),
    Neighborhood(name: 'حي المتنبي', latitude: 32.030647503988334, longitude: 44.38266102041013),
    Neighborhood(name: 'حي المثنى', latitude: 31.99912663250187, longitude: 44.34448442711137),
    Neighborhood(name: 'حي المرحلين', latitude: 32.01611070014482, longitude: 44.33646109047613),
    Neighborhood(name: 'حي المعلمين', latitude: 31.99273538973644, longitude: 44.3401778584111),
    Neighborhood(name: 'حي المكرمة', latitude: 32.06230655222661, longitude: 44.32594211721888),
    Neighborhood(name: 'حي المهندسين', latitude: 32.03400225538525, longitude: 44.3135416934223),
    Neighborhood(name: 'حي الميلاد', latitude: 32.05176454978557, longitude: 44.31270197320495),
    Neighborhood(name: 'حي النداء', latitude: 32.079403622680566, longitude: 44.30757208318381),
    Neighborhood(name: 'حي النصر', latitude: 32.041474945424476, longitude: 44.31325266834865),
    Neighborhood(name: 'حي النفط', latitude: 32.02160961260607, longitude: 44.32800625098189),
    Neighborhood(name: 'حي الهندية', latitude: 32.054857440412235, longitude: 44.34340122018436),
    Neighborhood(name: 'حي الوفاء', latitude: 32.04876110800057, longitude: 44.34690650567454),
    Neighborhood(name: 'حي عدن', latitude: 31.993176550307187, longitude: 44.34976404916102),
    Neighborhood(name: 'حي كندة 1', latitude: 32.02615764669632, longitude: 44.38848593789461),
    Neighborhood(name: 'حي كندة 2', latitude: 32.02176226729833, longitude: 44.38871132622159),
    Neighborhood(name: 'حي ميثم التمار', latitude: 32.01911264351798, longitude: 44.39056868264109),
    Neighborhood(name: 'حي ميسان', latitude: 32.05154644260673, longitude: 44.36236593351947),
    Neighborhood(name: 'خان المخضر', latitude: 31.996902540072213, longitude: 44.32922622329257),
    Neighborhood(name: 'شارع المدينة', latitude: 31.9917764055857, longitude: 44.32384620866347),
    Neighborhood(name: 'قرية الغدير', latitude: 32.08636097926253, longitude: 44.3306111844946),
    Neighborhood(name: 'مجمع الاميرات الأولى', latitude: 32.08156635127761, longitude: 44.29434881129866),
    Neighborhood(name: 'مجمع الاميرات الثانية', latitude: 32.09078306370191, longitude: 44.279154962855536),
    Neighborhood(name: 'مجمع الكرار', latitude: 32.08866229406901, longitude: 44.29259394417045),
    Neighborhood(name: 'مجمع المختار السكني', latitude: 32.026146848916504, longitude: 44.40837348765892),
    Neighborhood(name: 'مجمع عماد سكر', latitude: 31.996640043305735, longitude: 44.371777222699926),
    Neighborhood(name: 'مجمع قنبر', latitude: 32.10227446877997, longitude: 44.293514672922804),
  ];

  static List<Neighborhood> getAll() {
    return neighborhoods;
  }

  static Neighborhood? findByName(String name) {
    try {
      return neighborhoods.firstWhere((n) => n.name == name);
    } catch (e) {
      return null;
    }
  }
}

