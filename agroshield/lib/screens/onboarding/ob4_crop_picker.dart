import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class _Crop {
  final String id;
  final String emoji;
  final String nameEn;
  final String nameHi;
  const _Crop(this.id, this.emoji, this.nameEn, this.nameHi);
}

const _crops = [
  _Crop('cotton', '🌿', 'Cotton', 'कपास'),
  _Crop('wheat', '🌾', 'Wheat', 'गेहूँ'),
  _Crop('soybean', '🫘', 'Soybean', 'सोयाबीन'),
  _Crop('rice', '🍚', 'Rice', 'चावल'),
  _Crop('sugarcane', '🎋', 'Sugarcane', 'गन्ना'),
  _Crop('maize', '🌽', 'Maize', 'मक्का'),
  _Crop('groundnut', '🥜', 'Groundnut', 'मूँगफली'),
  _Crop('onion', '🧅', 'Onion', 'प्याज'),
  _Crop('other', '🌱', 'Other', 'अन्य'),
];

const _strings = {
  'en': {
    'title': 'What are you\ngrowing this season?',
    'subtitle': 'Select all that apply. You can update this in Settings.',
    'search': 'Search crops…',
    'nudge': 'You can add your crop later in Settings',
    'confirm': 'Continue',
  },
  'hi': {
    'title': 'इस मौसम में क्या\nउगा रहे हैं?',
    'subtitle': 'सभी फसलें चुनें। सेटिंग्स में बदल सकते हैं।',
    'search': 'फसल खोजें…',
    'nudge': 'बाद में सेटिंग्स में फसल जोड़ सकते हैं',
    'confirm': 'आगे बढ़ें',
  },
};

class Ob4CropPicker extends StatefulWidget {
  final String language;
  final void Function(List<String> crops) onConfirm;

  const Ob4CropPicker({super.key, required this.language, required this.onConfirm});

  @override
  State<Ob4CropPicker> createState() => _Ob4CropPickerState();
}

class _Ob4CropPickerState extends State<Ob4CropPicker> {
  final Set<String> _selected = {};
  final _searchController = TextEditingController();
  String _query = '';
  bool _showNudge = false;

  Map<String, String> get _s => _strings[widget.language] ?? _strings['en']!;

  List<_Crop> get _filtered {
    if (_query.isEmpty) return _crops;
    final q = _query.toLowerCase();
    return _crops
        .where((c) =>
            c.nameEn.toLowerCase().contains(q) ||
            c.nameHi.contains(q) ||
            c.id.contains(q))
        .toList();
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
      _showNudge = false;
    });
  }

  void _confirm() {
    if (_selected.isEmpty) {
      setState(() => _showNudge = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) widget.onConfirm([]);
      });
    } else {
      widget.onConfirm(_selected.toList());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crops = _filtered;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StepDots(current: 3, total: 6),
                  const SizedBox(height: 22),
                  Text(
                    _s['title']!,
                    style: GoogleFonts.fraunces(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _s['subtitle']!,
                    style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppTheme.textSub,
                        height: 1.4),
                  ),
                  const SizedBox(height: 14),

                  // Search bar
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    style: GoogleFonts.dmSans(fontSize: 15, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _s['search'],
                      prefixIcon:
                          const Icon(Icons.search, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Crop grid ───────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: crops.length,
                  itemBuilder: (_, i) {
                    final crop = crops[i];
                    final selected = _selected.contains(crop.id);
                    return _CropCard(
                      crop: crop,
                      selected: selected,
                      language: widget.language,
                      onTap: () => _toggle(crop.id),
                    );
                  },
                ),
              ),
            ),

            // ── Bottom CTA ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  if (_showNudge)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.amberStrip,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.amberBorder),
                      ),
                      child: Row(
                        children: [
                          const Text('🌱',
                              style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _s['nudge']!,
                              style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: AppTheme.amberText,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                  GestureDetector(
                    onTap: _confirm,
                    child: Container(
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accentDark]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_selected.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.bg.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_selected.length}',
                                style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.bg),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            _s['confirm']!,
                            style: GoogleFonts.dmSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.bg),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropCard extends StatelessWidget {
  final _Crop crop;
  final bool selected;
  final String language;
  final VoidCallback onTap;

  const _CropCard({
    required this.crop,
    required this.selected,
    required this.language,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x2E6FCF80), Color(0x1A43A853)])
              : null,
          color: selected ? null : AppTheme.bgNav,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppTheme.accent
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Text(crop.emoji,
                    style: const TextStyle(fontSize: 36)),
                if (selected)
                  Positioned(
                    top: -6,
                    right: -10,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check,
                          size: 13, color: AppTheme.bg),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              language == 'hi' ? crop.nameHi : crop.nameEn,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int current;
  final int total;
  const _StepDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i <= current;
        return Container(
          margin: const EdgeInsets.only(right: 6),
          width: i == current ? 24 : 8,
          height: 4,
          decoration: BoxDecoration(
            color: active ? AppTheme.accent : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
