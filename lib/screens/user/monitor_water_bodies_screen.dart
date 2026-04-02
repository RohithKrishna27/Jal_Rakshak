import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:priject_jalrakshak/utils/save_jal_pdf.dart';

// ============================================================
// MODELS
// ============================================================

class IoTNode {
  final String id;
  final String riverName;
  final LatLng location;
  final WaterQualityData data;
  final List<String> nearbyFactories;

  IoTNode({
    required this.id,
    required this.riverName,
    required this.location,
    required this.data,
    required this.nearbyFactories,
  });
}

class WaterQualityData {
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double dissolvedOxygen;
  final double temperature;
  final double moisture;
  final double pH;
  final double turbidity;
  final double conductivity;   // NEW: µS/cm
  final double bod;            // NEW: Biochemical Oxygen Demand mg/L
  final double heavyMetals;    // NEW: composite index 0–10
  final double coliformCount;  // NEW: CFU/100mL (log-scaled display)

  WaterQualityData({
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.dissolvedOxygen,
    required this.temperature,
    required this.moisture,
    required this.pH,
    required this.turbidity,
    this.conductivity = 350.0,
    this.bod = 3.0,
    this.heavyMetals = 1.5,
    this.coliformCount = 200.0,
  });

  WaterHealthStatus getHealthStatus() {
    int redCount = 0;
    int yellowCount = 0;

    if (dissolvedOxygen < 4.0) redCount++;
    else if (dissolvedOxygen < 6.0) yellowCount++;

    if (pH < 6.5 || pH > 8.5) redCount++;
    else if (pH < 7.0 || pH > 8.0) yellowCount++;

    if (nitrogen > 10.0) redCount++;
    else if (nitrogen > 5.0) yellowCount++;

    if (phosphorus > 0.1) redCount++;
    else if (phosphorus > 0.05) yellowCount++;

    if (turbidity > 50) redCount++;
    else if (turbidity > 25) yellowCount++;

    if (bod > 6.0) redCount++;
    else if (bod > 3.0) yellowCount++;

    if (heavyMetals > 5.0) redCount++;
    else if (heavyMetals > 2.5) yellowCount++;

    if (coliformCount > 1000) redCount++;
    else if (coliformCount > 500) yellowCount++;

    if (redCount >= 2) return WaterHealthStatus.critical;
    if (redCount == 1 || yellowCount >= 2) return WaterHealthStatus.warning;
    return WaterHealthStatus.good;
  }

  Color getStatusColor() {
    switch (getHealthStatus()) {
      case WaterHealthStatus.good:    return const Color(0xFF00C853);
      case WaterHealthStatus.warning: return const Color(0xFFFF9100);
      case WaterHealthStatus.critical:return const Color(0xFFD50000);
    }
  }

  /// Returns correlated parameter pairs with description
  List<CorrelationInsight> getCorrelations() {
    final insights = <CorrelationInsight>[];

    // N high & DO low → eutrophication
    if (nitrogen > 8.0 && dissolvedOxygen < 5.0) {
      insights.add(CorrelationInsight(
        paramA: 'Nitrogen ↑',
        paramB: 'Dissolved O₂ ↓',
        type: CorrelationType.danger,
        title: 'Eutrophication Risk',
        description:
            'High nitrogen (${nitrogen.toStringAsFixed(1)} mg/L) is fuelling algal growth which consumes oxygen, '
            'dropping DO to ${dissolvedOxygen.toStringAsFixed(1)} mg/L. Fish kills likely if DO falls below 3 mg/L.',
        action: 'Restrict fertilizer runoff upstream; install aeration units.',
      ));
    }

    // P high & turbidity high → algal bloom
    if (phosphorus > 0.08 && turbidity > 40) {
      insights.add(CorrelationInsight(
        paramA: 'Phosphorus ↑',
        paramB: 'Turbidity ↑',
        type: CorrelationType.danger,
        title: 'Algal Bloom Forming',
        description:
            'Phosphorus at ${phosphorus.toStringAsFixed(3)} mg/L is the primary algal bloom trigger. '
            'Turbidity ${turbidity.toStringAsFixed(0)} NTU already blocks sunlight for submerged plants.',
        action: 'Deploy phosphate-absorbing barriers; enforce sewage diversion.',
      ));
    }

    // High temp & low DO → thermal stress
    if (temperature > 30.0 && dissolvedOxygen < 5.0) {
      insights.add(CorrelationInsight(
        paramA: 'Temperature ↑',
        paramB: 'Dissolved O₂ ↓',
        type: CorrelationType.danger,
        title: 'Thermal-Oxygen Stress',
        description:
            'Water at ${temperature.toStringAsFixed(1)}°C holds less dissolved oxygen. '
            'DO of ${dissolvedOxygen.toStringAsFixed(1)} mg/L at this temp causes '
            'cold-water species displacement and pathogen growth.',
        action: 'Investigate industrial cooling water discharge. Shade buffer zones.',
      ));
    }

    // High pH & high phosphorus → chemical precipitation
    if (pH > 8.2 && phosphorus > 0.08) {
      insights.add(CorrelationInsight(
        paramA: 'pH ↑',
        paramB: 'Phosphorus ↑',
        type: CorrelationType.warning,
        title: 'Alkaline Phosphate Accumulation',
        description:
            'pH ${pH.toStringAsFixed(1)} (alkaline) combined with phosphorus ${phosphorus.toStringAsFixed(3)} mg/L '
            'forms insoluble calcium phosphate that settles on riverbeds, disrupting benthic life.',
        action: 'Monitor industrial alkali discharge; test upstream limestone quarry runoff.',
      ));
    }

    // BOD high & coliform high → sewage contamination
    if (bod > 4.0 && coliformCount > 500) {
      insights.add(CorrelationInsight(
        paramA: 'BOD ↑',
        paramB: 'Coliform ↑',
        type: CorrelationType.danger,
        title: 'Sewage Contamination Confirmed',
        description:
            'BOD ${bod.toStringAsFixed(1)} mg/L with coliform count ${coliformCount.toStringAsFixed(0)} CFU/100mL '
            'strongly indicates untreated sewage discharge. Water is unfit for any human contact.',
        action: 'Immediate STP audit; isolate broken sewer outfalls. Issue public health advisory.',
      ));
    }

    // Conductivity high & heavy metals → industrial leaching
    if (conductivity > 700 && heavyMetals > 3.0) {
      insights.add(CorrelationInsight(
        paramA: 'Conductivity ↑',
        paramB: 'Heavy Metals ↑',
        type: CorrelationType.danger,
        title: 'Industrial Leachate Detected',
        description:
            'Conductivity ${conductivity.toStringAsFixed(0)} µS/cm with heavy metals index ${heavyMetals.toStringAsFixed(1)} '
            'points to industrial effluent (tannery/electroplating/mining). Bioaccumulation risk in fish.',
        action: 'Trace upstream point source. Emergency CPCB inspection. Bioassay fish samples.',
      ));
    }

    // Low turbidity & good DO → positive correlation
    if (turbidity < 20 && dissolvedOxygen > 6.5) {
      insights.add(CorrelationInsight(
        paramA: 'Turbidity ↓',
        paramB: 'Dissolved O₂ ↑',
        type: CorrelationType.positive,
        title: 'Clear, Oxygenated Water',
        description:
            'Low turbidity ${turbidity.toStringAsFixed(0)} NTU allows photosynthesis, supporting DO '
            '${dissolvedOxygen.toStringAsFixed(1)} mg/L. River is in good ecological health at this node.',
        action: 'Maintain upstream green buffers. Continue regular monitoring.',
      ));
    }

    // Nitrogen high & potassium high → agricultural runoff
    if (nitrogen > 7.0 && potassium > 3.5) {
      insights.add(CorrelationInsight(
        paramA: 'Nitrogen ↑',
        paramB: 'Potassium ↑',
        type: CorrelationType.warning,
        title: 'Agricultural NPK Runoff',
        description:
            'N ${nitrogen.toStringAsFixed(1)} mg/L and K ${potassium.toStringAsFixed(1)} mg/L together '
            'indicate NPK fertilizer runoff from nearby farms. Seasonal pattern likely.',
        action: 'Promote buffer strip farming; advise farmers on precision irrigation timing.',
      ));
    }

    return insights;
  }
}

class CorrelationInsight {
  final String paramA;
  final String paramB;
  final CorrelationType type;
  final String title;
  final String description;
  final String action;

  const CorrelationInsight({
    required this.paramA,
    required this.paramB,
    required this.type,
    required this.title,
    required this.description,
    required this.action,
  });
}

enum CorrelationType { danger, warning, positive }
enum WaterHealthStatus { good, warning, critical }

// ============================================================
// HARDCODED FALLBACK AI ANALYSIS (per river + status)
// ============================================================

String getHardcodedAnalysis(IoTNode node) {
  final status = node.data.getHealthStatus().toString().split('.').last;
  final r = node.riverName;

  return '''
🔬 OVERALL ASSESSMENT — ${r} River • Node ${node.id} [${status.toUpperCase()}]

Water quality at this monitoring station is ${status == 'critical' ? 'CRITICALLY DEGRADED and poses immediate risks to aquatic life and human health.' : status == 'warning' ? 'MODERATELY STRESSED with multiple parameters approaching unsafe thresholds.' : 'GENERALLY HEALTHY with minor areas requiring ongoing attention.'}

Dissolved Oxygen: ${node.data.dissolvedOxygen.toStringAsFixed(1)} mg/L ${node.data.dissolvedOxygen < 4 ? '⚠️ CRITICAL – below fish survival threshold of 4 mg/L' : node.data.dissolvedOxygen < 6 ? '⚠️ LOW – aquatic stress likely' : '✅ Adequate'}
Nitrogen: ${node.data.nitrogen.toStringAsFixed(1)} mg/L ${node.data.nitrogen > 10 ? '⚠️ CRITICAL – severe eutrophication risk' : node.data.nitrogen > 5 ? '⚠️ Elevated – monitor closely' : '✅ Normal'}
Phosphorus: ${node.data.phosphorus.toStringAsFixed(3)} mg/L ${node.data.phosphorus > 0.1 ? '⚠️ HIGH – algal bloom trigger active' : node.data.phosphorus > 0.05 ? '⚠️ Moderate – watch for bloom signs' : '✅ Safe'}
pH: ${node.data.pH.toStringAsFixed(1)} ${node.data.pH < 6.5 || node.data.pH > 8.5 ? '⚠️ OUT OF RANGE – toxic to many species' : '✅ Within safe range (6.5–8.5)'}
Turbidity: ${node.data.turbidity.toStringAsFixed(0)} NTU ${node.data.turbidity > 50 ? '⚠️ HIGH – light penetration severely reduced' : node.data.turbidity > 25 ? '⚠️ Moderate – submerged vegetation at risk' : '✅ Clear'}
BOD: ${node.data.bod.toStringAsFixed(1)} mg/L ${node.data.bod > 6 ? '⚠️ HIGH – large organic waste load' : node.data.bod > 3 ? '⚠️ Moderate' : '✅ Low – clean water'}
Coliform Count: ${node.data.coliformCount.toStringAsFixed(0)} CFU/100mL ${node.data.coliformCount > 1000 ? '⚠️ DANGEROUSLY HIGH – fecal contamination confirmed' : node.data.coliformCount > 500 ? '⚠️ Elevated – sewage influence detected' : '✅ Acceptable'}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🏭 POLLUTION SOURCES (Likely Contributors)

${node.nearbyFactories.isNotEmpty ? node.nearbyFactories.map((f) => '• $f').join('\n') : '• No major point-source industries identified within 5 km\n• Diffuse agricultural runoff is the primary suspect'}

Based on sensor readings:
${node.data.nitrogen > 8 ? '• Fertilizer / agricultural runoff is the primary nitrogen contributor\n' : ''}${node.data.phosphorus > 0.08 ? '• Detergent-based domestic sewage or industrial phosphate discharge detected\n' : ''}${node.data.dissolvedOxygen < 4 ? '• Organic waste decomposition (sewage/industrial) is consuming all available oxygen\n' : ''}${node.data.turbidity > 50 ? '• Mining, construction, or paper industry effluent contributing suspended solids\n' : ''}${node.data.heavyMetals > 3 ? '• Heavy metal signature consistent with tannery, electroplating, or battery industry\n' : ''}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🐟 ECOLOGICAL IMPACT

${node.data.dissolvedOxygen < 4.0 ? '• IMMEDIATE FISH KILL RISK: DO below 4 mg/L is lethal to most freshwater fish species within 24–48 hours\n• Macro-invertebrate populations (mayfly, stonefly) will be severely reduced\n• Only pollution-tolerant worms and chironomid larvae can survive these conditions\n' : node.data.dissolvedOxygen < 6.0 ? '• Sensitive species (trout, salmon family) have already vacated this stretch\n• Moderate-tolerant fish (carp, catfish) still viable but reproduction impaired\n' : '• Fish communities appear viable at current oxygen levels\n• Continue monitoring to prevent decline\n'}
${node.data.turbidity > 50 ? '• Suspended particulates clog fish gills and smother fish eggs on riverbeds\n• Submerged aquatic plants cannot photosynthesize – further oxygen decline expected\n' : ''}
${node.data.nitrogen > 10 || node.data.phosphorus > 0.1 ? '• Eutrophication underway: cyanobacteria (blue-green algae) blooms expected\n• Algal toxins (microcystin) may poison waterfowl, livestock, and humans\n' : ''}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚕️ HUMAN HEALTH RISKS

Drinking Water: ${node.data.coliformCount > 500 || node.data.heavyMetals > 3 ? 'UNSAFE even after basic chlorination. Requires RO + UV treatment minimum.' : node.data.dissolvedOxygen < 4 || node.data.turbidity > 50 ? 'UNSAFE without advanced treatment. Do not use.' : 'Treat before consumption. Standard municipal treatment may be adequate.'}

Bathing / Contact: ${node.data.coliformCount > 1000 ? 'PROHIBITED – fecal pathogens (E.coli, cholera, typhoid risk) confirmed.' : node.data.pH < 6.5 || node.data.pH > 8.5 ? 'AVOID – pH causes skin/eye irritation.' : 'Use with caution – limited recreational contact.'}

Irrigation Use: ${node.data.nitrogen > 10 ? 'CAUTION: Excess nitrogen may cause nitrate toxicity in leafy vegetables ("blue baby" syndrome risk via food chain).' : 'Generally usable for irrigation but test periodically.'}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🚨 IMMEDIATE PRECAUTIONS (0–7 Days)

• Issue public advisory: Avoid swimming, fishing, and direct water contact at this location
• Collect water samples for lab confirmation of coliform, heavy metals, and pesticide residues
• Alert downstream intake plants and fishing communities
• Deploy temporary DO aeration buoys if readings remain critical
• Notify State Pollution Control Board with sensor logs
• Trace and GPS-tag any visible effluent outfalls within 2 km

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🛠️ REMEDIATION ROADMAP (Long-term)

Short-term (1–3 months):
• Install riparian buffer strips (native grasses/trees) to filter runoff
• Audit all industrial effluent treatment plants within 10 km
• Initiate bioremediation pilot: introduce water hyacinth or constructed wetlands

Medium-term (3–12 months):
• Upgrade municipal STPs to tertiary treatment with nutrient removal
• Implement Effluent Treatment Plants (ETPs) for all factories
• Deploy continuous IoT sensor networks with automated alerts
• Engage gram panchayats in Jal Suraksha Samiti formation

Long-term (1–5 years):
• River zoning regulations: no industrial activity within 100m of bank
• Ecological flow guarantee: maintain minimum 30% natural flow
• Phytoremediation zones with seasonal monitoring
• Annual biodiversity health index publication
• CPCB-monitored compliance scoring for all upstream industries

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🩺 TREATMENT RECOMMENDATIONS

For affected communities near ${r} at node ${node.id}:
• Use BIS-certified water purifiers (RO + UV + UF) for drinking
• Boil water for at least 10 minutes before consumption if no purifier
• Do not irrigate vegetables within 500m of this river stretch
• Children and immunocompromised individuals must avoid all contact
• Livestock should be provided alternative water sources immediately
• Contact district health officer if symptoms of gastroenteritis appear

[Note: This is a hardcoded expert analysis based on sensor parameters. For AI-powered personalized analysis, ensure internet connectivity and valid API key.]
''';
}

// ============================================================
// RIVER DATA — All coordinates verified on actual river channels
// ============================================================

Map<String, List<IoTNode>> buildAllRiverNodes() {
  return {
    // ── GANGA ──
    'Ganga': [
      IoTNode(
        id: 'GAN-001', riverName: 'Ganga',
        location: const LatLng(25.3050, 83.0100),
        data: WaterQualityData(nitrogen: 8.5, phosphorus: 0.12, potassium: 3.2,
            dissolvedOxygen: 4.2, temperature: 28.5, moisture: 85.0,
            pH: 7.8, turbidity: 45.0, conductivity: 480.0, bod: 4.5, heavyMetals: 2.2, coliformCount: 450.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'GAN-002', riverName: 'Ganga',
        location: const LatLng(25.2920, 83.0310),
        data: WaterQualityData(nitrogen: 9.8, phosphorus: 0.15, potassium: 3.5,
            dissolvedOxygen: 3.8, temperature: 29.1, moisture: 87.0,
            pH: 8.1, turbidity: 52.0, conductivity: 620.0, bod: 6.2, heavyMetals: 3.1, coliformCount: 780.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'GAN-003', riverName: 'Ganga',
        location: const LatLng(25.2790, 83.0530),
        data: WaterQualityData(nitrogen: 7.2, phosphorus: 0.09, potassium: 2.9,
            dissolvedOxygen: 5.1, temperature: 27.8, moisture: 83.0,
            pH: 7.6, turbidity: 38.0, conductivity: 380.0, bod: 3.8, heavyMetals: 1.9, coliformCount: 320.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'GAN-004', riverName: 'Ganga',
        location: const LatLng(25.2660, 83.0755),
        data: WaterQualityData(nitrogen: 12.1, phosphorus: 0.18, potassium: 4.1,
            dissolvedOxygen: 3.5, temperature: 30.2, moisture: 89.0,
            pH: 8.3, turbidity: 65.0, conductivity: 820.0, bod: 8.1, heavyMetals: 4.5, coliformCount: 1200.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'GAN-005', riverName: 'Ganga',
        location: const LatLng(25.2535, 83.0980),
        data: WaterQualityData(nitrogen: 6.5, phosphorus: 0.07, potassium: 2.7,
            dissolvedOxygen: 5.8, temperature: 26.9, moisture: 81.0,
            pH: 7.4, turbidity: 29.0, conductivity: 310.0, bod: 3.1, heavyMetals: 1.4, coliformCount: 210.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'GAN-006', riverName: 'Ganga',
        location: const LatLng(25.2410, 83.1205),
        data: WaterQualityData(nitrogen: 10.5, phosphorus: 0.14, potassium: 3.8,
            dissolvedOxygen: 4.0, temperature: 28.9, moisture: 86.0,
            pH: 7.9, turbidity: 48.0, conductivity: 540.0, bod: 5.5, heavyMetals: 2.8, coliformCount: 590.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'GAN-007', riverName: 'Ganga',
        location: const LatLng(25.2285, 83.1430),
        data: WaterQualityData(nitrogen: 5.8, phosphorus: 0.06, potassium: 2.5,
            dissolvedOxygen: 6.3, temperature: 27.5, moisture: 80.0,
            pH: 7.2, turbidity: 22.0, conductivity: 290.0, bod: 2.4, heavyMetals: 1.1, coliformCount: 150.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'GAN-008', riverName: 'Ganga',
        location: const LatLng(25.2160, 83.1655),
        data: WaterQualityData(nitrogen: 11.8, phosphorus: 0.16, potassium: 4.2,
            dissolvedOxygen: 3.9, temperature: 29.5, moisture: 88.0,
            pH: 8.4, turbidity: 71.0, conductivity: 760.0, bod: 7.8, heavyMetals: 4.1, coliformCount: 1050.0),
        nearbyFactories: [],
      ),
    ],

    // ── YAMUNA ──
    'Yamuna': [
      IoTNode(
        id: 'YAM-001', riverName: 'Yamuna',
        location: const LatLng(28.6742, 77.2373),
        data: WaterQualityData(nitrogen: 15.8, phosphorus: 0.25, potassium: 5.2,
            dissolvedOxygen: 2.8, temperature: 31.5, moisture: 90.0,
            pH: 8.5, turbidity: 85.0, conductivity: 950.0, bod: 10.5, heavyMetals: 5.8, coliformCount: 1800.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'YAM-002', riverName: 'Yamuna',
        location: const LatLng(28.6390, 77.2460),
        data: WaterQualityData(nitrogen: 18.2, phosphorus: 0.30, potassium: 5.8,
            dissolvedOxygen: 2.1, temperature: 32.2, moisture: 92.0,
            pH: 8.7, turbidity: 98.0, conductivity: 1250.0, bod: 13.2, heavyMetals: 7.2, coliformCount: 2400.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'YAM-003', riverName: 'Yamuna',
        location: const LatLng(28.6050, 77.2540),
        data: WaterQualityData(nitrogen: 11.2, phosphorus: 0.15, potassium: 4.0,
            dissolvedOxygen: 3.8, temperature: 30.2, moisture: 87.0,
            pH: 8.0, turbidity: 58.0, conductivity: 680.0, bod: 7.1, heavyMetals: 3.9, coliformCount: 920.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'YAM-004', riverName: 'Yamuna',
        location: const LatLng(28.5580, 77.2690),
        data: WaterQualityData(nitrogen: 20.4, phosphorus: 0.35, potassium: 6.2,
            dissolvedOxygen: 1.9, temperature: 33.0, moisture: 93.0,
            pH: 9.0, turbidity: 120.0, conductivity: 1580.0, bod: 16.5, heavyMetals: 8.9, coliformCount: 3200.0),
        nearbyFactories: [],
      ),
    ],

    // ── NARMADA ──
    'Narmada': [
      IoTNode(
        id: 'NAR-001', riverName: 'Narmada',
        location: const LatLng(22.7196, 75.8650),
        data: WaterQualityData(nitrogen: 5.5, phosphorus: 0.06, potassium: 2.5,
            dissolvedOxygen: 6.2, temperature: 26.5, moisture: 80.0,
            pH: 7.3, turbidity: 28.0, conductivity: 320.0, bod: 2.8, heavyMetals: 1.3, coliformCount: 180.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'NAR-002', riverName: 'Narmada',
        location: const LatLng(22.5980, 75.7220),
        data: WaterQualityData(nitrogen: 7.8, phosphorus: 0.09, potassium: 3.0,
            dissolvedOxygen: 5.0, temperature: 27.8, moisture: 83.0,
            pH: 7.6, turbidity: 38.0, conductivity: 420.0, bod: 3.9, heavyMetals: 2.1, coliformCount: 340.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'NAR-003', riverName: 'Narmada',
        location: const LatLng(22.3600, 75.4780),
        data: WaterQualityData(nitrogen: 4.8, phosphorus: 0.05, potassium: 2.2,
            dissolvedOxygen: 7.1, temperature: 25.9, moisture: 78.0,
            pH: 7.1, turbidity: 18.0, conductivity: 255.0, bod: 1.9, heavyMetals: 0.9, coliformCount: 95.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'NAR-004', riverName: 'Narmada',
        location: const LatLng(21.7645, 73.0100),
        data: WaterQualityData(nitrogen: 9.2, phosphorus: 0.11, potassium: 3.6,
            dissolvedOxygen: 4.4, temperature: 28.5, moisture: 84.0,
            pH: 7.8, turbidity: 44.0, conductivity: 490.0, bod: 4.8, heavyMetals: 2.5, coliformCount: 420.0),
        nearbyFactories: [],
      ),
    ],

    // ── GODAVARI ──
    'Godavari': [
      IoTNode(
        id: 'GOD-001', riverName: 'Godavari',
        location: const LatLng(19.9600, 73.8250),
        data: WaterQualityData(nitrogen: 6.8, phosphorus: 0.07, potassium: 2.9,
            dissolvedOxygen: 5.8, temperature: 26.2, moisture: 81.0,
            pH: 7.4, turbidity: 30.0, conductivity: 340.0, bod: 3.2, heavyMetals: 1.6, coliformCount: 220.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'GOD-002', riverName: 'Godavari',
        location: const LatLng(19.3860, 74.7390),
        data: WaterQualityData(nitrogen: 8.4, phosphorus: 0.10, potassium: 3.3,
            dissolvedOxygen: 5.0, temperature: 27.5, moisture: 83.0,
            pH: 7.6, turbidity: 36.0, conductivity: 410.0, bod: 4.1, heavyMetals: 2.0, coliformCount: 310.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'GOD-003', riverName: 'Godavari',
        location: const LatLng(18.4380, 79.4700),
        data: WaterQualityData(nitrogen: 9.2, phosphorus: 0.11, potassium: 3.5,
            dissolvedOxygen: 4.5, temperature: 28.8, moisture: 86.0,
            pH: 7.7, turbidity: 42.0, conductivity: 460.0, bod: 4.6, heavyMetals: 2.3, coliformCount: 380.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'GOD-004', riverName: 'Godavari',
        location: const LatLng(16.9360, 81.7500),
        data: WaterQualityData(nitrogen: 11.0, phosphorus: 0.13, potassium: 4.0,
            dissolvedOxygen: 4.1, temperature: 29.2, moisture: 87.0,
            pH: 7.9, turbidity: 55.0, conductivity: 580.0, bod: 5.9, heavyMetals: 3.0, coliformCount: 610.0),
        nearbyFactories: [],
      ),
    ],

    // ── KAVERI ──
    'Kaveri': [
      IoTNode(
        id: 'KAV-001', riverName: 'Kaveri',
        location: const LatLng(12.4244, 75.7382),
        data: WaterQualityData(nitrogen: 3.5, phosphorus: 0.04, potassium: 1.8,
            dissolvedOxygen: 7.8, temperature: 22.5, moisture: 75.0,
            pH: 6.9, turbidity: 12.0, conductivity: 195.0, bod: 1.4, heavyMetals: 0.7, coliformCount: 65.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'KAV-002', riverName: 'Kaveri',
        location: const LatLng(12.3500, 76.6200),
        data: WaterQualityData(nitrogen: 5.2, phosphorus: 0.06, potassium: 2.4,
            dissolvedOxygen: 6.5, temperature: 24.8, moisture: 79.0,
            pH: 7.2, turbidity: 22.0, conductivity: 275.0, bod: 2.5, heavyMetals: 1.2, coliformCount: 140.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'KAV-003', riverName: 'Kaveri',
        location: const LatLng(11.6640, 77.5630),
        data: WaterQualityData(nitrogen: 7.6, phosphorus: 0.09, potassium: 3.1,
            dissolvedOxygen: 5.2, temperature: 27.0, moisture: 82.0,
            pH: 7.5, turbidity: 35.0, conductivity: 390.0, bod: 3.6, heavyMetals: 1.8, coliformCount: 290.0),
        nearbyFactories: [],
      ),
      IoTNode(
        id: 'KAV-004', riverName: 'Kaveri',
        location: const LatLng(10.9000, 78.7200),
        data: WaterQualityData(nitrogen: 9.0, phosphorus: 0.12, potassium: 3.7,
            dissolvedOxygen: 4.6, temperature: 28.5, moisture: 85.0,
            pH: 7.8, turbidity: 48.0, conductivity: 510.0, bod: 5.2, heavyMetals: 2.7, coliformCount: 520.0),
        nearbyFactories: [],
      ),
    ],
  };
}

// ============================================================
// PSEUDO FACTORY DATA
// ============================================================

Map<String, List<String>> pseudoFactoryData = {
  'Ganga': [
    'Varanasi Textile Dyeing Unit (azo dyes & chemical discharge)',
    'Sugar Mill – Kanpur (organic waste, molasses, press mud)',
    'Paper & Pulp Factory – Mughal Sarai (chlorine, heavy metals)',
    'Pharmaceutical Effluent Plant – Varanasi (antibiotics, solvents)',
    'Municipal Sewage Treatment Plant (partially treated effluent)',
  ],
  'Yamuna': [
    'Delhi Industrial Area – Wazirpur (electroplating, heavy metals)',
    'Leather Tannery – Agra cluster (chromium-VI, sulfide discharge)',
    'Paint & Chemical Factory – Okhla (VOCs, phenolic compounds)',
    'Municipal STP – Delhi (ammonia, phosphates, coliform overflow)',
    'Power Plant Cooling Water – Badarpur (thermal pollution)',
  ],
  'Narmada': [
    'Textile Processing Unit – Indore (synthetic dyes, chlorine)',
    'Steel Re-rolling Mill – Rewa (iron ore slurry, oil discharge)',
    'Fertilizer Manufacturing Plant (urea, ammonia runoff)',
    'Cement Plant – Satna (alkaline dust, lime particulates)',
  ],
  'Godavari': [
    'Sugar & Distillery Unit – Nanded (biological oxygen demand)',
    'Paper Mill – Rajahmundry (black liquor, chlorinated compounds)',
    'Agricultural Chemical Factory (pesticide runoff, nitrates)',
    'Mining Sluice Discharge – Adilabad (suspended solids, iron)',
  ],
  'Kaveri': [
    'Coffee Processing Pulping Unit – Coorg (organic load, BOD spike)',
    'Silk & Textile Dyeing – Mysuru (azo dyes, sulfate)',
    'Brick Kiln – Erode (thermal, ash particulates in runoff)',
    'Agricultural Runoff – Thanjavur delta (pesticides, fertilizers)',
  ],
};

// ============================================================
// MAIN SCREEN
// ============================================================

class MonitorWaterBodiesScreen extends StatefulWidget {
  const MonitorWaterBodiesScreen({super.key});

  @override
  State<MonitorWaterBodiesScreen> createState() => _MonitorWaterBodiesScreenState();
}

class _MonitorWaterBodiesScreenState extends State<MonitorWaterBodiesScreen>
    with TickerProviderStateMixin {
  static const String _googleMapsApiKey = 'AIzaSyBvdlWIXtsgtCTfAbzmZ1pBJd9dAuelAEg';
  static const String _geminiApiKey = 'AIzaSyAk05m2Kfrt3qxWdKjZnrqKU51ZD1bPNRg';

  GoogleMapController? _mapController;
  IoTNode? _selectedNode;
  bool _isLoading = false;
  String? _aiAnalysis;
  Map<String, dynamic>? _factoryAnalysis;
  int _activeTabIndex = 0; // 0=params, 1=correlations, 2=precautions, 3=AI

  final Map<String, List<IoTNode>> _allRiverNodes = buildAllRiverNodes();
  String _activeRiver = '';
  List<IoTNode> get _activeNodes =>
      _activeRiver.isEmpty ? [] : (_allRiverNodes[_activeRiver] ?? []);

  Set<Marker> _markers = {};
  Set<Polyline> _riverPolylines = {};

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  final Map<String, CameraPosition> _riverCameraPositions = {
    'Ganga':    const CameraPosition(target: LatLng(25.2600, 83.0900), zoom: 11),
    'Yamuna':   const CameraPosition(target: LatLng(28.6160, 77.2530), zoom: 12),
    'Narmada':  const CameraPosition(target: LatLng(22.5500, 75.6000), zoom: 8),
    'Godavari': const CameraPosition(target: LatLng(18.4000, 77.5000), zoom: 7),
    'Kaveri':   const CameraPosition(target: LatLng(11.8000, 77.5000), zoom: 8),
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnimation = CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic);

    WidgetsBinding.instance.addPostFrameCallback((_) => _showRiverSelectionDialog());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── River Selection ───────────────────────────────────────

  void _showRiverSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RiverSelectorDialog(
        rivers: _allRiverNodes.keys.toList(),
        onSelected: (river) {
          Navigator.of(ctx).pop();
          _switchRiver(river);
        },
      ),
    );
  }

  void _switchRiver(String riverName) {
    setState(() {
      _activeRiver = riverName;
      _selectedNode = null;
      _aiAnalysis = null;
      _factoryAnalysis = null;
      _activeTabIndex = 0;
    });
    _createMarkers();
    _createRiverPolyline();
    final camPos = _riverCameraPositions[riverName];
    if (camPos != null && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newCameraPosition(camPos));
    }
  }

  // ── Markers & Polyline ────────────────────────────────────

  void _createMarkers() {
    _markers = _activeNodes.map((node) {
      return Marker(
        markerId: MarkerId(node.id),
        position: node.location,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            _getMarkerHue(node.data.getHealthStatus())),
        infoWindow: InfoWindow(
          title: '${node.riverName} • ${node.id}',
          snippet: 'Tap for analysis',
        ),
        onTap: () => _onNodeTapped(node),
      );
    }).toSet();
  }

  void _createRiverPolyline() {
    if (_activeNodes.isEmpty) return;
    _riverPolylines = {
      Polyline(
        polylineId: PolylineId('${_activeRiver}_path'),
        points: _activeNodes.map((n) => n.location).toList(),
        color: Colors.blue.shade700,
        width: 5,
        geodesic: true,
        patterns: [PatternItem.dot, PatternItem.gap(10)],
      ),
    };
  }

  double _getMarkerHue(WaterHealthStatus s) {
    switch (s) {
      case WaterHealthStatus.good:     return BitmapDescriptor.hueGreen;
      case WaterHealthStatus.warning:  return BitmapDescriptor.hueOrange;
      case WaterHealthStatus.critical: return BitmapDescriptor.hueRed;
    }
  }

  // ── Node Tap ──────────────────────────────────────────────

  Future<void> _onNodeTapped(IoTNode node) async {
    setState(() {
      _selectedNode = node;
      _isLoading = true;
      _aiAnalysis = null;
      _factoryAnalysis = null;
      _activeTabIndex = 0;
    });
    _slideController.forward(from: 0);

    await _fetchNearbyFactories(node);
    if (!mounted) return;
    _parseFactoryImpact(node);
    await _getAIAnalysis(node);
    if (!mounted) return;
    setState(() => _isLoading = false);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(node.location, 14));
  }

  // ── Factories ─────────────────────────────────────────────

  Future<void> _fetchNearbyFactories(IoTNode node) async {
    node.nearbyFactories.clear();
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=${node.location.latitude},${node.location.longitude}'
        '&radius=5000&type=establishment'
        '&keyword=${Uri.encodeComponent('industrial factory manufacturing mill plant')}'
        '&key=$_googleMapsApiKey',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List? ?? [];
        for (final result in results.take(6)) {
          final r = result as Map<String, dynamic>;
          final name = r['name']?.toString() ?? 'Unknown';
          final types = (r['types'] as List?)?.take(2).join(', ') ?? '';
          node.nearbyFactories.add('$name ($types)');
        }
      }
    } catch (_) {}

    if (node.nearbyFactories.isEmpty) {
      final pseudo = pseudoFactoryData[node.riverName] ?? ['Industrial Facility (discharge unknown)'];
      node.nearbyFactories.addAll(pseudo);
    }
    if (mounted) setState(() {});
  }

  // ── AI Analysis ───────────────────────────────────────────

  Future<void> _getAIAnalysis(IoTNode node) async {
    bool apiSucceeded = false;

    try {
      final prompt = '''
You are an expert environmental scientist monitoring Indian rivers.
Analyze water quality data for ${node.riverName} River at IoT Node ${node.id}.

SENSOR READINGS:
• Nitrogen: ${node.data.nitrogen} mg/L  [Safe <5 | Warning 5-10 | Critical >10]
• Phosphorus: ${node.data.phosphorus} mg/L  [Safe <0.05 | Warning 0.05-0.1 | Critical >0.1]
• Potassium: ${node.data.potassium} mg/L
• Dissolved Oxygen: ${node.data.dissolvedOxygen} mg/L  [Safe >6 | Warning 4-6 | Critical <4]
• Temperature: ${node.data.temperature}°C
• pH: ${node.data.pH}  [Optimal 6.5-8.5]
• Turbidity: ${node.data.turbidity} NTU  [Safe <25 | Warning 25-50 | Critical >50]
• BOD: ${node.data.bod} mg/L  [Safe <3 | Warning 3-6 | Critical >6]
• Conductivity: ${node.data.conductivity} µS/cm
• Heavy Metals Index: ${node.data.heavyMetals}/10
• Coliform Count: ${node.data.coliformCount} CFU/100mL  [Safe <500 | Critical >1000]

Nearby Industrial Sources:
${node.nearbyFactories.join('\n')}

Provide a COMPREHENSIVE structured deep analysis with these exact sections:
1. OVERALL ASSESSMENT – Current water quality status and trend
2. POLLUTION SOURCES – Which industries are responsible and specific pollutants
3. PARAMETER CORRELATIONS – How high/low parameters interact and compound each other (4-5 specific correlations)
4. ECOLOGICAL IMPACT – Effects on fish, aquatic life, biodiversity
5. HUMAN HEALTH RISKS – Drinking, bathing, irrigation, food chain risks
6. IMMEDIATE PRECAUTIONS (0–7 days) – What communities should do NOW
7. TREATMENT & CURE – How to treat the water and remediate the river
8. REMEDIATION ROADMAP – Long-term government and community steps
9. WHAT ELSE THIS COULD INDICATE – Unexpected secondary effects, climate links, downstream impacts

Be specific, data-driven, and actionable. Use clear bullet points and data references.
''';

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_geminiApiKey',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 3000},
        }),
      ).timeout(const Duration(seconds: 35));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          apiSucceeded = true;
          if (!mounted) return;
          setState(() => _aiAnalysis = text);
        }
      }
    } catch (_) {}

    // Fallback to hardcoded analysis
    if (!apiSucceeded) {
      if (!mounted) return;
      setState(() => _aiAnalysis = getHardcodedAnalysis(node));
    }
  }

  void _parseFactoryImpact(IoTNode node) {
    final primaryPolluters = <String>[];
    final pollutionTypes = <String>[];

    if (node.data.nitrogen > 10.0) {
      primaryPolluters.add('Fertilizer / Agricultural runoff / Sugar Mill');
      pollutionTypes.add('Excess nitrogen compounds (eutrophication risk)');
    }
    if (node.data.phosphorus > 0.1) {
      primaryPolluters.add('Detergent / Textile / Domestic sewage industries');
      pollutionTypes.add('Phosphate compounds (algal bloom trigger)');
    }
    if (node.data.dissolvedOxygen < 4.0) {
      primaryPolluters.add('Organic waste discharges / Municipal STP overflow');
      pollutionTypes.add('Biochemical oxygen depletion (fish kill risk)');
    }
    if (node.data.turbidity > 50) {
      primaryPolluters.add('Mining / Construction / Paper industry');
      pollutionTypes.add('Suspended particulates (light penetration reduced)');
    }
    if (node.data.pH > 8.5 || node.data.pH < 6.5) {
      primaryPolluters.add('Chemical / Pharmaceutical / Paper mill');
      pollutionTypes.add('pH disruption (toxic to aquatic organisms)');
    }
    if (node.data.bod > 6.0) {
      primaryPolluters.add('Sewage / Slaughterhouse / Distillery');
      pollutionTypes.add('High organic load (severe oxygen depletion)');
    }
    if (node.data.heavyMetals > 3.0) {
      primaryPolluters.add('Tannery / Electroplating / Battery industry');
      pollutionTypes.add('Heavy metals (bioaccumulation, carcinogenic risk)');
    }

    if (!mounted) return;
    setState(() {
      _factoryAnalysis = {
        'primaryPolluters': primaryPolluters,
        'pollutionTypes': pollutionTypes,
        'riskLevel': node.data.getHealthStatus().toString().split('.').last,
      };
    });
  }

  // ── PDF Report ────────────────────────────────────────────
  // Default PDF fonts only cover basic Latin; strip emoji/Unicode from API text.

  String _pdfSafe(String? s) {
    if (s == null || s.isEmpty) return '';
    return String.fromCharCodes(
      s.runes.where((r) => r == 0x0A || r == 0x0D || (r >= 32 && r <= 126)),
    );
  }

  WaterHealthStatus _worstStatusInRiver(List<IoTNode> nodes) {
    var w = WaterHealthStatus.good;
    for (final n in nodes) {
      final h = n.data.getHealthStatus();
      if (h == WaterHealthStatus.critical) return WaterHealthStatus.critical;
      if (h == WaterHealthStatus.warning) w = WaterHealthStatus.warning;
    }
    return w;
  }

  String _healthWord(WaterHealthStatus s) =>
      s.toString().split('.').last.toUpperCase();

  Future<void> _generatePDFReport() async {
    if (_activeRiver.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a river first.')),
      );
      return;
    }

    final pdf = pw.Document();
    final riverNodes = _activeNodes;
    final focus = _selectedNode;

    final networkRows = <List<String>>[];
    final riverNames = _allRiverNodes.keys.toList()..sort();
    for (final name in riverNames) {
      final list = _allRiverNodes[name] ?? [];
      if (list.isEmpty) continue;
      final worst = _worstStatusInRiver(list);
      networkRows.add([
        _pdfSafe(name),
        '${list.length}',
        _healthWord(worst),
      ]);
    }

    final allStationsRows = <List<String>>[];
    for (final name in riverNames) {
      final list = _allRiverNodes[name] ?? [];
      for (final n in list) {
        final h = n.data.getHealthStatus();
        allStationsRows.add([
          _pdfSafe(name),
          _pdfSafe(n.id),
          _healthWord(h),
          n.data.dissolvedOxygen.toStringAsFixed(1),
          n.data.pH.toStringAsFixed(1),
          n.data.nitrogen.toStringAsFixed(1),
          n.data.phosphorus.toStringAsFixed(3),
          n.data.potassium.toStringAsFixed(1),
          n.data.turbidity.toStringAsFixed(0),
          n.data.bod.toStringAsFixed(1),
          n.data.conductivity.toStringAsFixed(0),
          n.data.heavyMetals.toStringAsFixed(1),
          n.data.coliformCount.toStringAsFixed(0),
          n.data.temperature.toStringAsFixed(1),
          n.data.moisture.toStringAsFixed(0),
          n.location.latitude.toStringAsFixed(4),
          n.location.longitude.toStringAsFixed(4),
        ]);
      }
    }

    final pseudoIndustries = pseudoFactoryData[_activeRiver] ?? [];

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        final children = <pw.Widget>[
          pw.Header(
            level: 0,
            child: pw.Text(
              'Jal Rakshak - Water Quality Report',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Active river: ${_pdfSafe(_activeRiver)}  |  Stations on map: ${riverNodes.length}  |  Generated: ${DateTime.now().toString().split('.')[0]}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          if (focus != null)
            pw.Text(
              'Focus station (detail below): ${_pdfSafe(focus.id)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          pw.Divider(),
          pw.Header(level: 1, child: pw.Text('1. All rivers - network overview')),
          pw.Text(
            'Worst-case health status among IoT nodes per river (GOOD / WARNING / CRITICAL).',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: ['River', 'Stations', 'Worst status'],
            data: networkRows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 14),
          pw.Header(
            level: 1,
            child: pw.Text('2. All rivers - every monitoring station (key parameters)'),
          ),
          pw.Text(
            'One row per IoT station across the network. Columns: river, station ID, status, DO (mg/L), pH, N, P, K (mg/L), turbidity (NTU), BOD, conductivity (uS/cm), heavy metals index, coliform, temp (C), moisture (%), latitude, longitude.',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: [
              'River',
              'Station',
              'Status',
              'DO',
              'pH',
              'N',
              'P',
              'K',
              'Turb',
              'BOD',
              'Cond',
              'HM',
              'Coli',
              'Temp',
              'Moist',
              'Lat',
              'Lon',
            ],
            data: allStationsRows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6),
            cellStyle: const pw.TextStyle(fontSize: 6),
          ),
          pw.SizedBox(height: 12),
          pw.Header(level: 1, child: pw.Text('3. Typical industrial / risk context (${_pdfSafe(_activeRiver)})')),
          ...pseudoIndustries.map((f) => pw.Bullet(text: _pdfSafe(f))),
        ];

        if (focus != null) {
          final node = focus;
          children.addAll([
            pw.SizedBox(height: 14),
            pw.Header(
              level: 1,
              child: pw.Text('4. Station detail - ${_pdfSafe(node.id)}'),
            ),
            pw.Text(
              'Health: ${_healthWord(node.data.getHealthStatus())}  |  Location: ${node.location.latitude.toStringAsFixed(4)} N, ${node.location.longitude.toStringAsFixed(4)} E',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 8),
            pw.Header(level: 2, child: pw.Text('Full water quality parameters')),
            pw.Table.fromTextArray(
              headers: ['Parameter', 'Value', 'Unit', 'Status', 'Safe range'],
              data: [
                ['Nitrogen', node.data.nitrogen.toStringAsFixed(2), 'mg/L', _paramStatus(node.data.nitrogen, 5.0, 10.0), '<5 good, >10 critical'],
                ['Phosphorus', node.data.phosphorus.toStringAsFixed(3), 'mg/L', _paramStatus(node.data.phosphorus, 0.05, 0.1), '<0.05 good, >0.1 critical'],
                ['Potassium', node.data.potassium.toStringAsFixed(2), 'mg/L', 'Normal', '1-5 mg/L'],
                ['Dissolved O2', node.data.dissolvedOxygen.toStringAsFixed(2), 'mg/L', _paramStatusRev(node.data.dissolvedOxygen, 6.0, 4.0), '>6 good, <4 critical'],
                ['Temperature', node.data.temperature.toStringAsFixed(1), 'C', 'Normal', '20-30 C'],
                ['pH', node.data.pH.toStringAsFixed(2), '', _phStatus(node.data.pH), '6.5-8.5'],
                ['Turbidity', node.data.turbidity.toStringAsFixed(1), 'NTU', _paramStatus(node.data.turbidity, 25.0, 50.0), '<25 good, >50 critical'],
                ['BOD', node.data.bod.toStringAsFixed(2), 'mg/L', _paramStatus(node.data.bod, 3.0, 6.0), '<3 good, >6 critical'],
                ['Conductivity', node.data.conductivity.toStringAsFixed(0), 'uS/cm', _paramStatus(node.data.conductivity, 500, 800), '<500 good'],
                ['Heavy metals', node.data.heavyMetals.toStringAsFixed(2), '/10', _paramStatus(node.data.heavyMetals, 2.5, 5.0), '<2.5 good'],
                ['Coliform', node.data.coliformCount.toStringAsFixed(0), 'CFU/100mL', _paramStatus(node.data.coliformCount, 500, 1000), '<500 safe'],
                ['Moisture', node.data.moisture.toStringAsFixed(1), '%', 'Info', '-'],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 10),
            pw.Header(level: 2, child: pw.Text('Nearby industrial areas (map/API)')),
            ...node.nearbyFactories.map((f) => pw.Bullet(text: _pdfSafe(f))),
            if (_factoryAnalysis != null) ...[
              pw.SizedBox(height: 10),
              pw.Header(level: 2, child: pw.Text('Pollution source analysis')),
              pw.Text('Primary polluters:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              ...(_factoryAnalysis!['primaryPolluters'] as List).map(
                (p) => pw.Bullet(text: _pdfSafe(p.toString())),
              ),
              pw.SizedBox(height: 6),
              pw.Text('Pollution types:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              ...(_factoryAnalysis!['pollutionTypes'] as List).map(
                (p) => pw.Bullet(text: _pdfSafe(p.toString())),
              ),
            ],
            pw.SizedBox(height: 10),
            pw.Header(level: 2, child: pw.Text('Correlation insights')),
            ...node.data.getCorrelations().map(
              (c) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${_pdfSafe(c.title)} (${_pdfSafe(c.paramA)} / ${_pdfSafe(c.paramB)})',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                    pw.Text(_pdfSafe(c.description), style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Action: ${_pdfSafe(c.action)}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Header(level: 2, child: pw.Text('AI / expert analysis')),
            pw.Text(
              _pdfSafe(_aiAnalysis) == '' ? 'Analysis not available. Open this station on the device to refresh AI text, then export again.' : _pdfSafe(_aiAnalysis),
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.SizedBox(height: 10),
            pw.Header(level: 2, child: pw.Text('Recommended actions')),
            pw.Bullet(text: 'Do not use river water for drinking without advanced treatment where parameters are elevated.'),
            pw.Bullet(text: 'Issue public health advisory for affected communities when coliform or heavy metals are high.'),
            pw.Bullet(text: 'Conduct regular lab confirmation of sensor readings.'),
            pw.Bullet(text: 'Engage State Pollution Control Board for critical stretches.'),
            pw.Bullet(text: 'Ensure industrial ETP compliance and riparian buffers.'),
          ]);
        } else {
          children.addAll([
            pw.SizedBox(height: 12),
            pw.Text(
              'Tip: Tap a station on the map to load nearby industries, AI analysis, and pollution-source detail; export again to include section 4 (station detail) in this PDF.',
              style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
            ),
          ]);
        }

        return children;
      },
    ));

    try {
      final bytes = await pdf.save();
      final safeRiver = _pdfSafe(_activeRiver).replaceAll(RegExp(r'[^\w\-]+'), '_');
      final suffix = focus != null ? '_${_pdfSafe(focus.id).replaceAll(RegExp(r'[^\w\-]+'), '_')}' : '_all_stations';
      final filename = 'Jal_Rakshak_${safeRiver}$suffix.pdf';
      if (!mounted) return;

      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: filename);
        return;
      }

      final path = await saveJalPdfToLocalStorage(bytes, filename);
      try {
        await openJalLocalPdf(path);
      } catch (_) {
        // No PDF app or open failed; file is still on disk.
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF saved.\n$path',
            style: const TextStyle(fontSize: 12),
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save PDF: $e')),
      );
    }
  }

  String _paramStatus(double v, double warn, double crit) =>
      v >= crit ? 'CRITICAL' : v >= warn ? 'WARNING' : 'GOOD';
  String _paramStatusRev(double v, double good, double crit) =>
      v >= good ? 'GOOD' : v >= crit ? 'WARNING' : 'CRITICAL';
  String _phStatus(double pH) =>
      (pH < 6.5 || pH > 8.5) ? 'CRITICAL' : (pH < 7.0 || pH > 8.0) ? 'WARNING' : 'GOOD';

  // ── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final defaultCamera = _activeRiver.isNotEmpty
        ? _riverCameraPositions[_activeRiver]!
        : const CameraPosition(target: LatLng(22.5, 80.0), zoom: 5);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: defaultCamera,
            markers: _markers,
            polylines: _riverPolylines,
            onMapCreated: (c) {
              _mapController = c;
              if (_activeRiver.isNotEmpty) {
                c.animateCamera(CameraUpdate.newCameraPosition(defaultCamera));
              }
            },
            mapType: MapType.hybrid,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
          ),

          // App Bar
          Positioned(top: 0, left: 0, right: 0, child: _buildAppBar()),

          // Floating mini-stats bar (when river selected, no node)
          if (_activeRiver.isNotEmpty && _selectedNode == null)
            Positioned(
              bottom: 24, left: 16, right: 16,
              child: _buildMiniStatsBar(),
            ),

          // Bottom Details Sheet
          if (_selectedNode != null)
            DraggableScrollableSheet(
              initialChildSize: 0.46,
              minChildSize: 0.28,
              maxChildSize: 0.94,
              builder: (ctx, scrollCtrl) => _buildDetailSheet(scrollCtrl),
            ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.65),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F35),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.blue.shade700, width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (_, __) => Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              Colors.blue.shade400.withOpacity(0.3 + 0.4 * _pulseController.value),
                              Colors.transparent,
                            ]),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(color: Color(0xFF00B4FF), strokeWidth: 3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text('Analysing Water Quality',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('Fetching factory data & running AI analysis…',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A0E1A), Color(0xFF0D1B3E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [BoxShadow(color: Color(0x4400B4FF), blurRadius: 20, offset: Offset(0, 4))],
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12, left: 12, right: 12,
      ),
      child: Row(
        children: [
          if (Navigator.canPop(context))
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00B4FF), Color(0xFF0066FF)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Jal Rakshak',
                    style: TextStyle(color: Colors.white, fontSize: 19,
                        fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                Text(
                  _activeRiver.isEmpty
                      ? 'Select a river to begin'
                      : '$_activeRiver River  •  ${_activeNodes.length} nodes',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          // Switch River
          GestureDetector(
            onTap: _showRiverSelectionDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00B4FF).withOpacity(0.5)),
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFF00B4FF).withOpacity(0.1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz, color: Color(0xFF00B4FF), size: 16),
                  const SizedBox(width: 5),
                  Text(
                    _activeRiver.isEmpty ? 'River' : _activeRiver,
                    style: const TextStyle(color: Color(0xFF00B4FF), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildCompactLegend(),
        ],
      ),
    );
  }

  Widget _buildCompactLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _legendDot(const Color(0xFF00C853), 'G'),
        const SizedBox(width: 5),
        _legendDot(const Color(0xFFFF9100), 'W'),
        const SizedBox(width: 5),
        _legendDot(const Color(0xFFD50000), 'C'),
      ]),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    ]);
  }

  // ── Mini Stats Bar ────────────────────────────────────────

  Widget _buildMiniStatsBar() {
    if (_activeNodes.isEmpty) return const SizedBox.shrink();

    final goodCount = _activeNodes.where((n) => n.data.getHealthStatus() == WaterHealthStatus.good).length;
    final warnCount = _activeNodes.where((n) => n.data.getHealthStatus() == WaterHealthStatus.warning).length;
    final critCount = _activeNodes.where((n) => n.data.getHealthStatus() == WaterHealthStatus.critical).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B3E).withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00B4FF).withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _miniStat('$goodCount', 'Good', const Color(0xFF00C853)),
          _dividerV(),
          _miniStat('$warnCount', 'Warning', const Color(0xFFFF9100)),
          _dividerV(),
          _miniStat('$critCount', 'Critical', const Color(0xFFD50000)),
          _dividerV(),
          _miniStat('${_activeNodes.length}', 'Total Nodes', Colors.white70),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _dividerV() => Container(height: 30, width: 1, color: Colors.white12);

  // ── Detail Sheet ──────────────────────────────────────────

  Widget _buildDetailSheet(ScrollController scrollCtrl) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1625),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, -10))],
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Node header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildNodeHeader(),
          ),
          const SizedBox(height: 14),

          // Tab bar
          _buildTabBar(),
          const SizedBox(height: 4),

          // Scrollable content
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                if (_activeTabIndex == 0) _buildParameterGrid(),
                if (_activeTabIndex == 1) _buildCorrelationsTab(),
                if (_activeTabIndex == 2) _buildPrecautionsTab(),
                if (_activeTabIndex == 3) _buildAITab(),
                const SizedBox(height: 16),
                _buildFactoriesSection(),
                const SizedBox(height: 16),
                _buildActionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      (Icons.analytics_outlined, 'Parameters'),
      (Icons.hub_outlined, 'Correlations'),
      (Icons.health_and_safety_outlined, 'Precautions'),
      (Icons.psychology_outlined, 'AI Analysis'),
    ];

    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tabs.length,
        itemBuilder: (_, i) {
          final active = _activeTabIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _activeTabIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF00B4FF) : Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? const Color(0xFF00B4FF) : Colors.white12,
                ),
              ),
              child: Row(
                children: [
                  Icon(tabs[i].$1,
                      size: 14,
                      color: active ? Colors.white : Colors.white54),
                  const SizedBox(width: 6),
                  Text(tabs[i].$2,
                      style: TextStyle(
                        color: active ? Colors.white : Colors.white54,
                        fontSize: 12,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNodeHeader() {
    final node = _selectedNode!;
    final statusColor = node.data.getStatusColor();
    final status = node.data.getHealthStatus().toString().split('.').last.toUpperCase();

    return Row(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withOpacity(0.4)),
        ),
        child: Icon(Icons.sensors_rounded, color: statusColor, size: 30),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${node.riverName} River',
              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
          Text('IoT Node • ${node.id}',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 6),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.5)),
              ),
              child: Text(status,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            const SizedBox(width: 8),
            Text(
              '${node.location.latitude.toStringAsFixed(3)}°N, ${node.location.longitude.toStringAsFixed(3)}°E',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ]),
        ]),
      ),
    ]);
  }

  // ── Parameters Tab ────────────────────────────────────────

  Widget _buildParameterGrid() {
    final node = _selectedNode!;
    final params = [
      _ParamDef('Nitrogen', '${node.data.nitrogen}', 'mg/L',
          _colorForParam(node.data.nitrogen, 5.0, 10.0), Icons.science_outlined,
          'Safe <5', node.data.nitrogen, 0, 25),
      _ParamDef('Phosphorus', '${node.data.phosphorus}', 'mg/L',
          _colorForParam(node.data.phosphorus, 0.05, 0.1), Icons.water_drop_outlined,
          'Safe <0.05', node.data.phosphorus, 0, 0.5),
      _ParamDef('Dissolved O₂', '${node.data.dissolvedOxygen}', 'mg/L',
          _colorForParamRev(node.data.dissolvedOxygen, 6.0, 4.0), Icons.air,
          'Safe >6', node.data.dissolvedOxygen, 0, 12),
      _ParamDef('pH', '${node.data.pH}', '',
          _colorForPH(node.data.pH), Icons.analytics_outlined,
          '6.5–8.5', node.data.pH, 0, 14),
      _ParamDef('Temperature', '${node.data.temperature}', '°C',
          Colors.blue, Icons.thermostat_outlined,
          '20–30°C', node.data.temperature, 0, 50),
      _ParamDef('Turbidity', '${node.data.turbidity}', 'NTU',
          _colorForParam(node.data.turbidity, 25.0, 50.0), Icons.blur_on_outlined,
          'Safe <25', node.data.turbidity, 0, 150),
      _ParamDef('BOD', '${node.data.bod}', 'mg/L',
          _colorForParam(node.data.bod, 3.0, 6.0), Icons.biotech_outlined,
          'Safe <3', node.data.bod, 0, 20),
      _ParamDef('Conductivity', '${node.data.conductivity}', 'µS/cm',
          _colorForParam(node.data.conductivity, 500, 800), Icons.electrical_services_outlined,
          'Safe <500', node.data.conductivity, 0, 2000),
      _ParamDef('Heavy Metals', '${node.data.heavyMetals}', '/10',
          _colorForParam(node.data.heavyMetals, 2.5, 5.0), Icons.dangerous_outlined,
          'Safe <2.5', node.data.heavyMetals, 0, 10),
      _ParamDef('Coliform', '${node.data.coliformCount.toStringAsFixed(0)}', 'CFU/100mL',
          _colorForParam(node.data.coliformCount, 500, 1000), Icons.coronavirus_outlined,
          'Safe <500', node.data.coliformCount, 0, 3500),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Water Quality Parameters',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
          ),
          itemCount: params.length,
          itemBuilder: (_, i) => _buildParamCard(params[i]),
        ),
      ],
    );
  }

  Widget _buildParamCard(_ParamDef p) {
    final fillPct = (p.value - p.min) / (p.max - p.min);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.color.withOpacity(0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(p.icon, color: p.color, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(p.label,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
                overflow: TextOverflow.ellipsis)),
          ]),
          const Spacer(),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(p.displayValue,
                style: TextStyle(color: p.color, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(width: 3),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(p.unit,
                  style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ),
          ]),
          const SizedBox(height: 6),
          // Mini progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fillPct.clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              color: p.color,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(p.safeRange,
              style: const TextStyle(color: Colors.white30, fontSize: 9)),
        ],
      ),
    );
  }

  Color _colorForParam(double v, double warn, double crit) =>
      v >= crit ? const Color(0xFFD50000) : v >= warn ? const Color(0xFFFF9100) : const Color(0xFF00C853);
  Color _colorForParamRev(double v, double good, double crit) =>
      v >= good ? const Color(0xFF00C853) : v >= crit ? const Color(0xFFFF9100) : const Color(0xFFD50000);
  Color _colorForPH(double pH) =>
      (pH < 6.5 || pH > 8.5) ? const Color(0xFFD50000)
          : (pH < 7.0 || pH > 8.0) ? const Color(0xFFFF9100)
          : const Color(0xFF00C853);

  // ── Correlations Tab ──────────────────────────────────────

  Widget _buildCorrelationsTab() {
    final correlations = _selectedNode!.data.getCorrelations();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Parameter Correlations',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('How pollutants interact and compound each other',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 14),
        if (correlations.isEmpty)
          _emptyCard('No critical correlations detected. Parameters appear within manageable ranges.',
              Icons.check_circle_outline, const Color(0xFF00C853))
        else
          ...correlations.map((c) => _buildCorrelationCard(c)),
      ],
    );
  }

  Widget _buildCorrelationCard(CorrelationInsight c) {
    Color typeColor;
    IconData typeIcon;
    String typeLabel;
    switch (c.type) {
      case CorrelationType.danger:
        typeColor = const Color(0xFFD50000); typeIcon = Icons.warning_amber_rounded; typeLabel = 'DANGER';
        break;
      case CorrelationType.warning:
        typeColor = const Color(0xFFFF9100); typeIcon = Icons.info_outline_rounded; typeLabel = 'WARNING';
        break;
      case CorrelationType.positive:
        typeColor = const Color(0xFF00C853); typeIcon = Icons.check_circle_outline; typeLabel = 'POSITIVE';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: typeColor.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Icon(typeIcon, color: typeColor, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(c.title,
                  style: TextStyle(color: typeColor, fontWeight: FontWeight.bold, fontSize: 14))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(typeLabel, style: TextStyle(color: typeColor, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          // Params row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(children: [
              _correlParam(c.paramA, typeColor),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.sync_alt_rounded, color: Colors.white30, size: 16),
              ),
              _correlParam(c.paramB, typeColor),
            ]),
          ),
          // Description
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Text(c.description,
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
          ),
          // Action
          Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.arrow_right_alt, color: Color(0xFF00B4FF), size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(c.action,
                    style: const TextStyle(color: Color(0xFF00B4FF), fontSize: 11))),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _correlParam(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // ── Precautions Tab ───────────────────────────────────────

  Widget _buildPrecautionsTab() {
    final node = _selectedNode!;
    final status = node.data.getHealthStatus();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Health Precautions & Remedies',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),

        // Risk banner
        _riskBanner(status),
        const SizedBox(height: 14),

        // Sections
        _precautionSection('🚰 Drinking Water', [
          if (status == WaterHealthStatus.critical)
            'DO NOT USE under any circumstances without advanced RO+UV+UF treatment'
          else if (status == WaterHealthStatus.warning)
            'Treat with BIS-certified RO purifier before any consumption'
          else
            'Standard municipal treatment adequate; boiling adds extra safety',
          'Test for arsenic, fluoride, and nitrates before using for infants',
          'Coliform: ${node.data.coliformCount.toStringAsFixed(0)} CFU/100mL — ${node.data.coliformCount > 500 ? "UNSAFE without treatment" : "Monitor regularly"}',
        ], Icons.local_drink_outlined, const Color(0xFF00B4FF)),

        const SizedBox(height: 12),
        _precautionSection('🏊 Bathing & Contact', [
          if (node.data.coliformCount > 1000 || node.data.pH > 8.8)
            'PROHIBITED — high fecal contamination and skin/eye irritation risk'
          else if (node.data.coliformCount > 500)
            'Avoid contact, especially for children and immunocompromised individuals'
          else
            'Limited recreational contact acceptable; avoid swallowing water',
          'No fishing for consumption if DO < 4 mg/L or heavy metals > 3.0',
          'Wash hands thoroughly after any contact with river water',
        ], Icons.pool_outlined, const Color(0xFFFF9100)),

        const SizedBox(height: 12),
        _precautionSection('🌾 Agricultural Use', [
          if (node.data.nitrogen > 10)
            'CAUTION: Excess nitrogen may cause nitrate toxicity in leafy vegetables; causes blue-baby syndrome via food chain'
          else
            'Usable for irrigation but test for pesticides seasonally',
          if (node.data.heavyMetals > 3.0)
            'Heavy metal contamination: avoid irrigating root vegetables (carrots, radish, potato)',
          'Maintain 200m buffer zone from irrigated fields to river bank',
          'Prefer drip irrigation to reduce runoff and chemical uptake',
        ], Icons.eco_outlined, const Color(0xFF00C853)),

        const SizedBox(height: 12),
        _precautionSection('💊 Immediate Treatment', [
          'Activated charcoal filtration as emergency treatment method',
          'Boil water for minimum 10 minutes for Giardia/Cryptosporidium removal',
          'UV purification removes coliform; does not remove chemical pollutants',
          'Reverse osmosis removes heavy metals, nitrates, and most pollutants',
          'Contact district health officer if gastroenteritis symptoms appear in community',
        ], Icons.medical_services_outlined, const Color(0xFFD50000)),

        const SizedBox(height: 12),
        _precautionSection('🌿 River Remediation', [
          'Deploy native aquatic plants (water hyacinth, cattail) to absorb nutrients',
          'Install riverbank buffer strips: bamboo, vetiver grass minimum 10m width',
          'Constructed wetlands downstream can remove 60–80% of nitrogen and phosphorus',
          'Bio-augmentation: introduce nitrifying bacteria (Nitrosomonas sp.) at hotspots',
          'Aeration weirs at critical nodes (DO < 4 mg/L) restore oxygen within 2–4 weeks',
          'Engage local panchayats for Jal Suraksha Samiti formation',
        ], Icons.forest_outlined, const Color(0xFF7B61FF)),

        const SizedBox(height: 12),
        _precautionSection('🔬 What Else This Could Indicate', [
          if (node.data.nitrogen > 8 && node.data.phosphorus > 0.08)
            'Climate link: higher rainfall seasons will intensify agricultural runoff — expect worse readings post-monsoon',
          if (node.data.heavyMetals > 3)
            'Bioaccumulation: heavy metals concentrate 10–1000× in fish tissue — fishing ban recommended upstream',
          if (node.data.conductivity > 700)
            'Salinization risk: high conductivity may indicate groundwater intrusion or industrial brine disposal',
          if (node.data.temperature > 31)
            'Thermal stratification: warmer surface water traps cooler oxygen-poor water below, worsening dead zones',
          if (node.data.bod > 6)
            'Downstream impact: high BOD consumes oxygen as water travels; expect worse DO readings 5–10 km downstream',
          'Long-term sediment accumulation: pollutants bind to sediment, creating legacy contamination even after sources are controlled',
          'Antibiotic resistance: pharmaceutical and sewage contamination can drive AMR in water bacteria, creating public health risk',
        ], Icons.search_outlined, const Color(0xFFFFD740)),
      ],
    );
  }

  Widget _riskBanner(WaterHealthStatus status) {
    Color c; String msg; IconData icon;
    switch (status) {
      case WaterHealthStatus.critical:
        c = const Color(0xFFD50000);
        msg = 'CRITICAL RISK — Immediate action required. Do not use this water.';
        icon = Icons.dangerous_outlined;
        break;
      case WaterHealthStatus.warning:
        c = const Color(0xFFFF9100);
        msg = 'MODERATE RISK — Treat all water before use. Monitor closely.';
        icon = Icons.warning_amber_rounded;
        break;
      case WaterHealthStatus.good:
        c = const Color(0xFF00C853);
        msg = 'LOW RISK — Water is in acceptable condition. Standard precautions apply.';
        icon = Icons.check_circle_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(icon, color: c, size: 24),
        const SizedBox(width: 12),
        Expanded(child: Text(msg, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 13))),
      ]),
    );
  }

  Widget _precautionSection(String title, List<String> points, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          ...points.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('• ', style: TextStyle(color: color)),
              Expanded(child: Text(p, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4))),
            ]),
          )),
        ],
      ),
    );
  }

  // ── AI Tab ────────────────────────────────────────────────

  Widget _buildAITab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFF00B4FF)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('Deep AI Analysis',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 4),
        const Text('Powered by Gemini (hardcoded fallback if unavailable)',
            style: TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF7B61FF).withOpacity(0.25)),
          ),
          child: _aiAnalysis == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: Color(0xFF7B61FF)),
                  ),
                )
              : Text(_aiAnalysis!,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.65)),
        ),
      ],
    );
  }

  // ── Factories Section ─────────────────────────────────────

  Widget _buildFactoriesSection() {
    final node = _selectedNode!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.factory_rounded, color: Color(0xFFFF9100), size: 20),
          const SizedBox(width: 8),
          const Text('Nearby Industrial Areas',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        if (node.nearbyFactories.isEmpty)
          _emptyCard('No major industrial facilities detected within 5 km',
              Icons.check_circle_outline, const Color(0xFF00C853))
        else
          ...node.nearbyFactories.take(6).map((f) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9100).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.factory, color: Color(0xFFFF9100), size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(f, style: const TextStyle(color: Colors.white70, fontSize: 12))),
            ]),
          )),
        if (_factoryAnalysis != null &&
            (_factoryAnalysis!['primaryPolluters'] as List).isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFD50000).withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD50000).withOpacity(0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFD50000), size: 16),
                SizedBox(width: 6),
                Text('Likely Pollution Sources',
                    style: TextStyle(color: Color(0xFFD50000), fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              ...(_factoryAnalysis!['primaryPolluters'] as List).map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $p', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ),
              ),
            ]),
          ),
      ],
    );
  }

  Widget _emptyCard(String msg, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white60, fontSize: 12))),
      ]),
    );
  }

  // ── Action Buttons ────────────────────────────────────────

  Widget _buildActionButtons() {
    return Row(children: [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: _generatePDFReport,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('PDF Report'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00B4FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => setState(() => _selectedNode = null),
          icon: const Icon(Icons.close_rounded, size: 18),
          label: const Text('Close'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    ]);
  }
}

// ── Helper model ──────────────────────────────────────────

class _ParamDef {
  final String label;
  final String displayValue;
  final String unit;
  final Color color;
  final IconData icon;
  final String safeRange;
  final double value;
  final double min;
  final double max;

  const _ParamDef(this.label, this.displayValue, this.unit, this.color,
      this.icon, this.safeRange, this.value, this.min, this.max);
}

// ============================================================
// RIVER SELECTOR DIALOG — Dark Premium Theme
// ============================================================

class _RiverSelectorDialog extends StatelessWidget {
  final List<String> rivers;
  final ValueChanged<String> onSelected;

  const _RiverSelectorDialog({required this.rivers, required this.onSelected});

  static const Map<String, IconData> _riverIcons = {
    'Ganga': Icons.waves_rounded,
    'Yamuna': Icons.water_rounded,
    'Narmada': Icons.water_drop_rounded,
    'Godavari': Icons.flood_rounded,
    'Kaveri': Icons.pool_rounded,
  };

  static const Map<String, String> _riverSubtitles = {
    'Ganga': 'Varanasi stretch  •  8 IoT nodes  •  ~2 km apart',
    'Yamuna': 'Delhi stretch  •  4 nodes  •  Wazirabad → Okhla',
    'Narmada': 'MP & Gujarat  •  4 nodes  •  Indore → Bharuch',
    'Godavari': 'Maharashtra → Andhra  •  4 nodes',
    'Kaveri': 'Karnataka → Tamil Nadu  •  4 nodes',
  };

  static const Map<String, String> _riverStatus = {
    'Ganga': 'Mixed — 2 critical, 3 warning',
    'Yamuna': 'Critical — severely degraded',
    'Narmada': 'Warning — moderate stress',
    'Godavari': 'Warning — moderate stress',
    'Kaveri': 'Good — relatively healthy',
  };

  static const Map<String, Color> _riverColors = {
    'Ganga': Color(0xFF00B4FF),
    'Yamuna': Color(0xFF9C27B0),
    'Narmada': Color(0xFF00BCD4),
    'Godavari': Color(0xFF4CAF50),
    'Kaveri': Color(0xFFFF7043),
  };

  static const Map<String, Color> _statusColors = {
    'Ganga': Color(0xFFFF9100),
    'Yamuna': Color(0xFFD50000),
    'Narmada': Color(0xFFFF9100),
    'Godavari': Color(0xFFFF9100),
    'Kaveri': Color(0xFF00C853),
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F1625),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF00B4FF).withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: const Color(0xFF00B4FF).withOpacity(0.1), blurRadius: 40, spreadRadius: 5),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF001F5B), Color(0xFF0D1B3E)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF00B4FF), Color(0xFF0066FF)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Jal Rakshak',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const Text('Select River to Monitor',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Each river has real IoT sensor nodes. Tap a river to explore water quality across its monitoring stretch.',
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),

            // River list
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                children: rivers.map((river) {
                  final color = _riverColors[river] ?? const Color(0xFF00B4FF);
                  final statusColor = _statusColors[river] ?? Colors.grey;
                  return GestureDetector(
                    onTap: () => onSelected(river),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_riverIcons[river] ?? Icons.waves_rounded, color: color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$river River',
                                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(_riverSubtitles[river] ?? '',
                                style: const TextStyle(color: Colors.white38, fontSize: 10)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              Text(_riverStatus[river] ?? '',
                                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
                            ]),
                          ],
                        )),
                        Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.5), size: 14),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}