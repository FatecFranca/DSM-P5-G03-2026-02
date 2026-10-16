import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/geo_coordinates.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Formulário para informar latitude e longitude manualmente.
class CoordinatesScreen extends ConsumerStatefulWidget {
  const CoordinatesScreen({super.key});

  @override
  ConsumerState<CoordinatesScreen> createState() => _CoordinatesScreenState();
}

class _CoordinatesScreenState extends ConsumerState<CoordinatesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  double? _parse(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  String? _validateLatitude(String? value) {
    final parsed = _parse(value ?? '');
    if (parsed == null) return 'Informe uma latitude válida.';
    if (parsed < -90 || parsed > 90) return 'A latitude deve estar entre -90 e 90.';
    return null;
  }

  String? _validateLongitude(String? value) {
    final parsed = _parse(value ?? '');
    if (parsed == null) return 'Informe uma longitude válida.';
    if (parsed < -180 || parsed > 180) {
      return 'A longitude deve estar entre -180 e 180.';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final coordinates = GeoCoordinates(
      latitude: _parse(_latitudeController.text)!,
      longitude: _parse(_longitudeController.text)!,
    );
    ref.read(coordinatesProvider.notifier).state = coordinates;
    context.go('/monitoring');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Digitar coordenadas',
          style: AppTypography.sora(
            AppColors.charcoal,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Informe sua latitude e longitude em graus decimais.',
                  style: AppTypography.inter(
                    AppColors.gray,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _CoordinateField(
                  controller: _latitudeController,
                  label: 'Latitude',
                  hint: 'Ex.: -20.5386',
                  validator: _validateLatitude,
                ),
                const SizedBox(height: AppSpacing.lg),
                _CoordinateField(
                  controller: _longitudeController,
                  label: 'Longitude',
                  hint: 'Ex.: -47.4008',
                  validator: _validateLongitude,
                ),
                const SizedBox(height: AppSpacing.xxl),
                FilledButton(
                  onPressed: _submit,
                  child: const Text('Confirmar coordenadas'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoordinateField extends StatelessWidget {
  const _CoordinateField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.inter(
            AppColors.charcoal,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: const TextInputType.numberWithOptions(
            signed: true,
            decimal: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
          ],
          style: AppTypography.mono(
            AppColors.charcoal,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
