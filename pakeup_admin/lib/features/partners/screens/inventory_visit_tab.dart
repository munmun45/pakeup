part of 'partner_inventory_screen.dart';

// ══════════════════════════════════════════════════════════════════
//  VISIT SETTINGS TAB
// ══════════════════════════════════════════════════════════════════

class _VisitSettingsTab extends ConsumerStatefulWidget {
  const _VisitSettingsTab({required this.services});
  final List<PartnerServiceRecord> services;

  @override
  ConsumerState<_VisitSettingsTab> createState() =>
      _VisitSettingsTabState();
}

class _VisitSettingsTabState extends ConsumerState<_VisitSettingsTab> {
  late Map<String, ServicePricingDraft> _drafts;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _buildDrafts();
  }

  @override
  void didUpdateWidget(_VisitSettingsTab old) {
    super.didUpdateWidget(old);
    if (old.services != widget.services) _buildDrafts();
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

  Future<void> _saveCard(ServicePricingDraft draft) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(serviceAvailabilityRepositoryProvider).updateServicePricing(
            callerId: user.id,
            serviceId: draft.serviceId,
            isParlourAvailable: draft.isParlourAvailable,
            parlourPriceMen: draft.parlourPriceMen,
            parlourDurationMen: draft.parlourDurationMen,
            parlourPriceWomen: draft.parlourPriceWomen,
            parlourDurationWomen: draft.parlourDurationWomen,
            isHomeAvailable: draft.isHomeAvailable,
            homePriceMen: draft.homePriceMen,
            homeDurationMen: draft.homeDurationMen,
            homePriceWomen: draft.homePriceWomen,
            homeDurationWomen: draft.homeDurationWomen,
            freeRadiusKm: draft.freeRadiusKm,
            perKmCharge: draft.perKmCharge,
            discountPrice: draft.discountPrice,
          );
      draft.isDirty = false;
      ref.invalidate(partnerServicesListProvider);
      if (mounted) AppSnackBar.success(context, '${draft.serviceName} updated!');
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.services.isEmpty) {
      return const Center(
        child: Text('No services found.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        childAspectRatio: 1.05,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: widget.services.length,
      itemBuilder: (context, i) {
        final s = widget.services[i];
        final draft = _drafts[s.id]!;
        return _VisitSettingsCard(
          service: s,
          draft: draft,
          saving: _saving,
          onChanged: () => setState(() {}),
          onSave: () => _saveCard(draft),
        );
      },
    );
  }
}

class _VisitSettingsCard extends StatefulWidget {
  const _VisitSettingsCard({
    required this.service,
    required this.draft,
    required this.saving,
    required this.onChanged,
    required this.onSave,
  });

  final PartnerServiceRecord service;
  final ServicePricingDraft draft;
  final bool saving;
  final VoidCallback onChanged;
  final VoidCallback onSave;

  @override
  State<_VisitSettingsCard> createState() => _VisitSettingsCardState();
}

class _VisitSettingsCardState extends State<_VisitSettingsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: d.isDirty
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.border,
          width: d.isDirty ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.spa_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.service.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.service.partnerName,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (d.isDirty)
                  IconButton(
                    icon: widget.saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded,
                            size: 18, color: AppColors.primary),
                    tooltip: 'Save',
                    onPressed: widget.saving ? null : widget.onSave,
                  ),
                IconButton(
                  icon: Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Visit type toggles
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Parlour toggle
                  _VisitToggleRow(
                    icon: Icons.storefront_outlined,
                    label: 'Parlour Visit',
                    value: d.isParlourAvailable,
                    color: const Color(0xFF8E54E9),
                    onChanged: (v) {
                      d.isParlourAvailable = v;
                      d.isDirty = true;
                      widget.onChanged();
                    },
                  ),

                  if (_expanded && d.isParlourAvailable) ...[
                    const SizedBox(height: 8),
                    _GenderPricingRow(
                      gender: 'Male',
                      icon: Icons.male_rounded,
                      color: const Color(0xFF4A90D9),
                      price: d.parlourPriceMen,
                      duration: d.parlourDurationMen,
                      onChanged: (price, duration) {
                        d.parlourPriceMen = price;
                        d.parlourDurationMen = duration;
                        d.isDirty = true;
                        widget.onChanged();
                      },
                    ),
                    const SizedBox(height: 6),
                    _GenderPricingRow(
                      gender: 'Female',
                      icon: Icons.female_rounded,
                      color: const Color(0xFFE91E8C),
                      price: d.parlourPriceWomen,
                      duration: d.parlourDurationWomen,
                      onChanged: (price, duration) {
                        d.parlourPriceWomen = price;
                        d.parlourDurationWomen = duration;
                        d.isDirty = true;
                        widget.onChanged();
                      },
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Home toggle
                  _VisitToggleRow(
                    icon: Icons.home_outlined,
                    label: 'Home Visit',
                    value: d.isHomeAvailable,
                    color: const Color(0xFF44A0E3),
                    onChanged: (v) {
                      d.isHomeAvailable = v;
                      d.isDirty = true;
                      widget.onChanged();
                    },
                  ),

                  if (_expanded && d.isHomeAvailable) ...[
                    const SizedBox(height: 8),
                    _GenderPricingRow(
                      gender: 'Male',
                      icon: Icons.male_rounded,
                      color: const Color(0xFF4A90D9),
                      price: d.homePriceMen,
                      duration: d.homeDurationMen,
                      onChanged: (price, duration) {
                        d.homePriceMen = price;
                        d.homeDurationMen = duration;
                        d.isDirty = true;
                        widget.onChanged();
                      },
                    ),
                    const SizedBox(height: 6),
                    _GenderPricingRow(
                      gender: 'Female',
                      icon: Icons.female_rounded,
                      color: const Color(0xFFE91E8C),
                      price: d.homePriceWomen,
                      duration: d.homeDurationWomen,
                      onChanged: (price, duration) {
                        d.homePriceWomen = price;
                        d.homeDurationWomen = duration;
                        d.isDirty = true;
                        widget.onChanged();
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: _CompactField(
                          label: 'Free Radius',
                          suffix: 'km',
                          initial: d.freeRadiusKm.toString(),
                          onChanged: (v) {
                            d.freeRadiusKm = int.tryParse(v) ?? 0;
                            d.isDirty = true;
                            widget.onChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CompactField(
                          label: 'Per KM',
                          prefix: '₹',
                          initial: d.perKmCharge.toStringAsFixed(0),
                          onChanged: (v) {
                            d.perKmCharge = double.tryParse(v) ?? 0;
                            d.isDirty = true;
                            widget.onChanged();
                          },
                        ),
                      ),
                    ]),
                  ],

                  if (!_expanded) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => setState(() => _expanded = true),
                      child: const Text(
                        'Tap ▲ to configure per-gender pricing...',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitToggleRow extends StatelessWidget {
  const _VisitToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: value
            ? color.withValues(alpha: 0.07)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: value
              ? color.withValues(alpha: 0.25)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 17,
              color: value ? color : AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: value ? color : AppColors.textSecondary,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _GenderPricingRow extends StatelessWidget {
  const _GenderPricingRow({
    required this.gender,
    required this.icon,
    required this.color,
    required this.price,
    required this.duration,
    required this.onChanged,
  });

  final String gender;
  final IconData icon;
  final Color color;
  final double? price;
  final int? duration;
  final void Function(double? price, int? duration) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        SizedBox(
          width: 44,
          child: Text(
            gender,
            style: TextStyle(
                fontSize: 11.5,
                color: color,
                fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: _CompactField(
            label: 'Price',
            prefix: '₹',
            initial: price?.toStringAsFixed(0) ?? '',
            onChanged: (v) {
              onChanged(
                  double.tryParse(v), duration);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompactField(
            label: 'Min',
            suffix: 'min',
            initial: duration?.toString() ?? '',
            onChanged: (v) {
              onChanged(price, int.tryParse(v));
            },
          ),
        ),
      ],
    );
  }
}

class _CompactField extends StatefulWidget {
  const _CompactField({
    required this.label,
    required this.initial,
    required this.onChanged,
    this.prefix,
    this.suffix,
  });

  final String label;
  final String initial;
  final ValueChanged<String> onChanged;
  final String? prefix;
  final String? suffix;

  @override
  State<_CompactField> createState() => _CompactFieldState();
}

class _CompactFieldState extends State<_CompactField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 12),
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle:
            const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
        prefixText: widget.prefix,
        suffixText: widget.suffix,
        prefixStyle: const TextStyle(fontSize: 11),
        suffixStyle: const TextStyle(fontSize: 10),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
