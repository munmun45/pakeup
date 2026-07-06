part of 'partner_inventory_screen.dart';

// ══════════════════════════════════════════════════════════════════
//  PRICING TAB
// ══════════════════════════════════════════════════════════════════

class _PricingTab extends ConsumerStatefulWidget {
  const _PricingTab({required this.services});
  final List<PartnerServiceRecord> services;

  @override
  ConsumerState<_PricingTab> createState() => _PricingTabState();
}

class _PricingTabState extends ConsumerState<_PricingTab> {
  late Map<String, ServicePricingDraft> _drafts;
  bool _saving = false;

  static const _headerStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
    color: AppColors.textSecondary,
  );

  @override
  void initState() {
    super.initState();
    _buildDrafts();
  }

  @override
  void didUpdateWidget(_PricingTab old) {
    super.didUpdateWidget(old);
    if (old.services != widget.services) {
      _buildDrafts();
    }
  }

  void _buildDrafts() {
    _drafts = {
      for (final s in widget.services)
        s.id: ServicePricingDraft(
          serviceId: s.id,
          partnerId: s.partnerId,
          serviceName: s.name,
          partnerName: s.partnerName,
          category: s.category,
          isParlourAvailable: s.isParlourAvailable,
          parlourPriceMen: s.parlourPriceMen,
          parlourDurationMen: s.parlourDurationMen,
          parlourPriceWomen: s.parlourPriceWomen,
          parlourDurationWomen: s.parlourDurationWomen,
          isHomeAvailable: s.isHomeAvailable,
          homePriceMen: s.homePriceMen,
          homeDurationMen: s.homeDurationMen,
          homePriceWomen: s.homePriceWomen,
          homeDurationWomen: s.homeDurationWomen,
          freeRadiusKm: s.freeRadiusKm,
          perKmCharge: s.perKmCharge,
          discountPrice: s.discountPrice,
        ),
    };
  }

  int get _dirtyCount => _drafts.values.where((d) => d.isDirty).length;

  Future<void> _saveAll() async {
    final dirty = _drafts.values.where((d) => d.isDirty).toList();
    if (dirty.isEmpty) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _saving = true);

    final repo = ref.read(serviceAvailabilityRepositoryProvider);
    int saved = 0;
    final errors = <String>[];

    for (final d in dirty) {
      try {
        await repo.updateServicePricing(
          callerId: user.id,
          serviceId: d.serviceId,
          isParlourAvailable: d.isParlourAvailable,
          parlourPriceMen: d.parlourPriceMen,
          parlourDurationMen: d.parlourDurationMen,
          parlourPriceWomen: d.parlourPriceWomen,
          parlourDurationWomen: d.parlourDurationWomen,
          isHomeAvailable: d.isHomeAvailable,
          homePriceMen: d.homePriceMen,
          homeDurationMen: d.homeDurationMen,
          homePriceWomen: d.homePriceWomen,
          homeDurationWomen: d.homeDurationWomen,
          freeRadiusKm: d.freeRadiusKm,
          perKmCharge: d.perKmCharge,
          discountPrice: d.discountPrice,
        );
        d.isDirty = false;
        saved++;
      } catch (e) {
        errors.add(d.serviceName);
      }
    }

    setState(() => _saving = false);

    if (!mounted) return;
    if (errors.isEmpty) {
      ref.invalidate(partnerServicesListProvider);
      AppSnackBar.success(context, '$saved service(s) pricing updated!');
    } else {
      AppSnackBar.warning(context,
          '$saved saved. Failed: ${errors.join(', ')}');
    }
  }

  void _openEditDialog(ServicePricingDraft draft) {
    showDialog<ServicePricingDraft?>(
      context: context,
      builder: (ctx) => _PricingEditDialog(draft: draft),
    ).then((updated) {
      if (updated != null) {
        setState(() => _drafts[updated.serviceId] = updated);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;

    if (services.isEmpty) {
      return const Center(
        child: Text('No services found for selected filter.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Save bar
        if (_dirtyCount > 0)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: AppColors.primary.withValues(alpha: 0.06),
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_note_rounded,
                      size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  '$_dirtyCount service(s) have unsaved pricing changes',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() => _buildDrafts());
                  },
                  child: const Text('Discard'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveAll,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Save All'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

        // Table header
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: const Color(0xFFFAF8FA),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('SERVICE', style: _headerStyle)),
              Expanded(flex: 2, child: Text('PARLOUR (M/F) ₹', style: _headerStyle)),
              Expanded(flex: 2, child: Text('HOME (M/F) ₹', style: _headerStyle)),
              Expanded(flex: 2, child: Text('DURATION (min)', style: _headerStyle)),
              SizedBox(width: 90, child: Text('DISCOUNT', style: _headerStyle)),
              SizedBox(width: 60, child: Text('EDIT', style: _headerStyle, textAlign: TextAlign.center)),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: services.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, i) {
              final s = services[i];
              final draft = _drafts[s.id]!;
              return _PricingRow(
                service: s,
                draft: draft,
                onEdit: () => _openEditDialog(draft),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PricingRow extends StatelessWidget {
  const _PricingRow({
    required this.service,
    required this.draft,
    required this.onEdit,
  });

  final PartnerServiceRecord service;
  final ServicePricingDraft draft;
  final VoidCallback onEdit;

  Widget _priceCell(double? men, double? women) {
    if (men == null && women == null) {
      return const Text('—', style: TextStyle(color: AppColors.textSecondary));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (men != null)
          Row(children: [
            const Icon(Icons.male_rounded, size: 11, color: Color(0xFF4A90D9)),
            const SizedBox(width: 3),
            Text('₹${men.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ]),
        if (women != null)
          Row(children: [
            const Icon(Icons.female_rounded, size: 11, color: Color(0xFFE91E8C)),
            const SizedBox(width: 3),
            Text('₹${women.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ]),
      ],
    );
  }

  Widget _durationCell(int? men, int? women) {
    if (men == null && women == null) {
      return const Text('—', style: TextStyle(color: AppColors.textSecondary));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (men != null)
          Text('M: ${men}m',
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
        if (women != null)
          Text('F: ${women}m',
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: draft.isDirty
          ? AppColors.primary.withValues(alpha: 0.02)
          : Colors.transparent,
      child: Row(
        children: [
          // Service name
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (draft.isDirty)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle),
                      ),
                    Flexible(
                      child: Text(
                        service.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  service.partnerName,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    service.category,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Parlour
          Expanded(
            flex: 2,
            child: draft.isParlourAvailable
                ? _priceCell(draft.parlourPriceMen, draft.parlourPriceWomen)
                : const Text('Disabled',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic)),
          ),

          // Home
          Expanded(
            flex: 2,
            child: draft.isHomeAvailable
                ? _priceCell(draft.homePriceMen, draft.homePriceWomen)
                : const Text('Disabled',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic)),
          ),

          // Duration
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (draft.isParlourAvailable)
                  Row(children: [
                    const Icon(Icons.storefront_outlined,
                        size: 10, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    _durationCell(
                        draft.parlourDurationMen, draft.parlourDurationWomen),
                  ]),
                if (draft.isHomeAvailable) ...[
                  if (draft.isParlourAvailable) const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.home_outlined,
                        size: 10, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    _durationCell(draft.homeDurationMen, draft.homeDurationWomen),
                  ]),
                ],
              ],
            ),
          ),

          // Discount
          SizedBox(
            width: 90,
            child: draft.discountPrice != null
                ? Text(
                    '₹${draft.discountPrice!.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  )
                : const Text('—',
                    style: TextStyle(color: AppColors.textSecondary)),
          ),

          // Edit button
          SizedBox(
            width: 60,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.primary),
                tooltip: 'Edit Pricing',
                onPressed: onEdit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full Pricing Edit Dialog ─────────────────────────────────
class _PricingEditDialog extends StatefulWidget {
  const _PricingEditDialog({required this.draft});
  final ServicePricingDraft draft;

  @override
  State<_PricingEditDialog> createState() => _PricingEditDialogState();
}

class _PricingEditDialogState extends State<_PricingEditDialog> {
  late bool _parlour;
  late bool _home;

  late final TextEditingController _parlourPriceMenCtrl;
  late final TextEditingController _parlourDurMenCtrl;
  late final TextEditingController _parlourPriceWomenCtrl;
  late final TextEditingController _parlourDurWomenCtrl;
  late final TextEditingController _homePriceMenCtrl;
  late final TextEditingController _homeDurMenCtrl;
  late final TextEditingController _homePriceWomenCtrl;
  late final TextEditingController _homeDurWomenCtrl;
  late final TextEditingController _radiusCtrl;
  late final TextEditingController _perKmCtrl;
  late final TextEditingController _discountCtrl;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _parlour = d.isParlourAvailable;
    _home = d.isHomeAvailable;
    _parlourPriceMenCtrl = TextEditingController(text: d.parlourPriceMen?.toStringAsFixed(0) ?? '');
    _parlourDurMenCtrl = TextEditingController(text: d.parlourDurationMen?.toString() ?? '');
    _parlourPriceWomenCtrl = TextEditingController(text: d.parlourPriceWomen?.toStringAsFixed(0) ?? '');
    _parlourDurWomenCtrl = TextEditingController(text: d.parlourDurationWomen?.toString() ?? '');
    _homePriceMenCtrl = TextEditingController(text: d.homePriceMen?.toStringAsFixed(0) ?? '');
    _homeDurMenCtrl = TextEditingController(text: d.homeDurationMen?.toString() ?? '');
    _homePriceWomenCtrl = TextEditingController(text: d.homePriceWomen?.toStringAsFixed(0) ?? '');
    _homeDurWomenCtrl = TextEditingController(text: d.homeDurationWomen?.toString() ?? '');
    _radiusCtrl = TextEditingController(text: d.freeRadiusKm.toString());
    _perKmCtrl = TextEditingController(text: d.perKmCharge.toStringAsFixed(0));
    _discountCtrl = TextEditingController(text: d.discountPrice?.toStringAsFixed(0) ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _parlourPriceMenCtrl, _parlourDurMenCtrl, _parlourPriceWomenCtrl,
      _parlourDurWomenCtrl, _homePriceMenCtrl, _homeDurMenCtrl,
      _homePriceWomenCtrl, _homeDurWomenCtrl, _radiusCtrl, _perKmCtrl,
      _discountCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  ServicePricingDraft _buildDraft() {
    double? pd(TextEditingController c) =>
        c.text.trim().isEmpty ? null : double.tryParse(c.text.trim());
    int? pi(TextEditingController c) =>
        c.text.trim().isEmpty ? null : int.tryParse(c.text.trim());

    return widget.draft.copyWith(
      isParlourAvailable: _parlour,
      parlourPriceMen: pd(_parlourPriceMenCtrl),
      parlourDurationMen: pi(_parlourDurMenCtrl),
      parlourPriceWomen: pd(_parlourPriceWomenCtrl),
      parlourDurationWomen: pi(_parlourDurWomenCtrl),
      isHomeAvailable: _home,
      homePriceMen: pd(_homePriceMenCtrl),
      homeDurationMen: pi(_homeDurMenCtrl),
      homePriceWomen: pd(_homePriceWomenCtrl),
      homeDurationWomen: pi(_homeDurWomenCtrl),
      freeRadiusKm: pi(_radiusCtrl) ?? 0,
      perKmCharge: pd(_perKmCtrl) ?? 0,
      discountPrice: pd(_discountCtrl),
    );
  }

  Widget _sectionLabel(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              )),
        ],
      ),
    );
  }

  Widget _genderRow(String gender, IconData gIcon, Color gColor,
      TextEditingController priceCtrl, TextEditingController durCtrl) {
    return Row(
      children: [
        Icon(gIcon, size: 14, color: gColor),
        const SizedBox(width: 6),
        SizedBox(
          width: 70,
          child: Text(gender,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: _MiniField(ctrl: priceCtrl, hint: '₹ Price', prefix: '₹'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniField(ctrl: durCtrl, hint: 'Minutes', suffix: 'min'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                    bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.price_change_outlined,
                      color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.draft.serviceName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(widget.draft.partnerName,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Parlour section
                    Row(
                      children: [
                        Expanded(
                          child: _sectionLabel(
                              'Parlour Visit', Icons.storefront_outlined),
                        ),
                        Switch(
                          value: _parlour,
                          onChanged: (v) => setState(() => _parlour = v),
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                    if (_parlour) ...[
                      _genderRow(
                        'Male',
                        Icons.male_rounded,
                        const Color(0xFF4A90D9),
                        _parlourPriceMenCtrl,
                        _parlourDurMenCtrl,
                      ),
                      const SizedBox(height: 8),
                      _genderRow(
                        'Female',
                        Icons.female_rounded,
                        const Color(0xFFE91E8C),
                        _parlourPriceWomenCtrl,
                        _parlourDurWomenCtrl,
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Home section
                    Row(
                      children: [
                        Expanded(
                          child: _sectionLabel(
                              'Home Visit', Icons.home_outlined),
                        ),
                        Switch(
                          value: _home,
                          onChanged: (v) => setState(() => _home = v),
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                    if (_home) ...[
                      _genderRow(
                        'Male',
                        Icons.male_rounded,
                        const Color(0xFF4A90D9),
                        _homePriceMenCtrl,
                        _homeDurMenCtrl,
                      ),
                      const SizedBox(height: 8),
                      _genderRow(
                        'Female',
                        Icons.female_rounded,
                        const Color(0xFFE91E8C),
                        _homePriceWomenCtrl,
                        _homeDurWomenCtrl,
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: _MiniField(
                                ctrl: _radiusCtrl,
                                hint: 'Free radius',
                                suffix: 'km',
                                label: 'Free Radius')),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _MiniField(
                                ctrl: _perKmCtrl,
                                hint: 'Per km charge',
                                prefix: '₹',
                                label: 'Per km Charge')),
                      ]),
                    ],

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Discount
                    _sectionLabel('Discount Price', Icons.local_offer_outlined),
                    _MiniField(
                      ctrl: _discountCtrl,
                      hint: 'Optional discount price',
                      prefix: '₹',
                      label: 'Discount Price',
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, _buildDraft()),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Apply'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
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

class _MiniField extends StatelessWidget {
  const _MiniField({
    required this.ctrl,
    required this.hint,
    this.prefix,
    this.suffix,
    this.label,
  });

  final TextEditingController ctrl;
  final String hint;
  final String? prefix;
  final String? suffix;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label!,
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textSecondary)),
          ),
        TextField(
          controller: ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12),
            prefixText: prefix,
            suffixText: suffix,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
