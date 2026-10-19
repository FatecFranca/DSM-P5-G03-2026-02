import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/flame_logo.dart';

/// Tela de configurações funcionais (tema, localização, notificações).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _locations = [
    'Franca, SP',
    'Ribeirão Preto, SP',
    'São Paulo, SP',
  ];
  static const _updates = ['A cada hora', 'A cada 3 horas', 'A cada 6 horas'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(locationProvider);
    final notifications = ref.watch(notificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void setNotification(String key, bool value) {
      ref.read(notificationsProvider.notifier).state = {
        ...notifications,
        key: value,
      };
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Configurações',
          style: AppTypography.sora(
            Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          // Aparência.
          _Section(
            title: 'Aparência',
            children: [
              _SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Tema',
                subtitle: isDark ? 'Tema escuro' : 'Tema claro',
                trailing: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Claro'),
                      icon: Icon(Icons.light_mode_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Escuro'),
                      icon: Icon(Icons.dark_mode_outlined, size: 18),
                    ),
                  ],
                  selected: {isDark},
                  onSelectionChanged: (selection) {
                    ref.read(themeModeProvider.notifier).state = selection.first
                        ? ThemeMode.dark
                        : ThemeMode.light;
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(
                      AppTypography.inter(
                        Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Localização.
          _Section(
            title: 'Localização',
            children: [
              _SettingsTile(
                icon: Icons.location_on_outlined,
                title: 'Localização selecionada',
                subtitle: location,
                trailing: Icon(
                  Icons.keyboard_arrow_right_rounded,
                  color: AppColors.grayLight,
                ),
                onTap: () async {
                  final selected = await showModalBottomSheet<String>(
                    context: context,
                    showDragHandle: true,
                    builder: (context) => SafeArea(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        children: [
                          for (final loc in _locations)
                            ListTile(
                              leading: Icon(
                                loc == location
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: loc == location
                                    ? AppColors.orange
                                    : null,
                              ),
                              title: Text(loc),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              onTap: () => Navigator.of(context).pop(loc),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (selected != null) {
                    ref.read(locationProvider.notifier).state = selected;
                  }
                },
              ),
            ],
          ),

          // Notificações.
          _Section(
            title: 'Notificações',
            children: [
              _SwitchTile(
                icon: Icons.warning_amber_rounded,
                title: 'Alertas de risco',
                value: notifications['riskAlerts'] ?? false,
                onChanged: (v) => setNotification('riskAlerts', v),
              ),
              _SwitchTile(
                icon: Icons.cloud_outlined,
                title: 'Atualizações meteorológicas',
                value: notifications['weatherUpdates'] ?? false,
                onChanged: (v) => setNotification('weatherUpdates', v),
              ),
              _SwitchTile(
                icon: Icons.eco_outlined,
                title: 'Dicas de prevenção',
                value: notifications['preventionTips'] ?? false,
                onChanged: (v) => setNotification('preventionTips', v),
              ),
            ],
          ),

          // Atualização.
          _Section(
            title: 'Preferências de atualização',
            children: [
              _SettingsTile(
                icon: Icons.refresh_rounded,
                title: 'Frequência de atualização',
                subtitle: 'Visual (demonstrativo)',
                trailing: _UpdateMenu(updates: _updates),
              ),
            ],
          ),

          // Sobre.
          _Section(
            title: 'Sobre o aplicativo',
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: FlameLogo(size: 64)),
              ),
              Center(
                child: FirewatchWordmarkText(
                  width: 160,
                  light: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
              const SizedBox(height: 2),
              Center(
                child: Text(
                  AppConstants.slogan,
                  style: AppTypography.inter(AppColors.gray, fontSize: 12),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Versão'),
                trailing: Text(
                  AppConstants.version,
                  style: AppTypography.mono(
                    AppColors.grayDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Firewatch ${AppConstants.version}')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
            child: Text(
              title.toUpperCase(),
              style: AppTypography.inter(
                scheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Material(
            color: scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1)
                    Divider(
                      height: 1,
                      indent: AppSpacing.lg + 40,
                      endIndent: AppSpacing.lg,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.orange, size: 22),
      title: Text(
        title,
        style: AppTypography.inter(
          Theme.of(context).colorScheme.onSurface,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: AppTypography.inter(AppColors.gray, fontSize: 12.5),
            ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.orange, size: 22),
      title: Text(
        title,
        style: AppTypography.inter(
          Theme.of(context).colorScheme.onSurface,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.orange,
    );
  }
}

class _UpdateMenu extends StatefulWidget {
  const _UpdateMenu({required this.updates});

  final List<String> updates;

  @override
  State<_UpdateMenu> createState() => _UpdateMenuState();
}

class _UpdateMenuState extends State<_UpdateMenu> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      initialValue: _index,
      tooltip: 'Frequência de atualização',
      onSelected: (i) => setState(() => _index = i),
      itemBuilder: (context) => [
        for (var i = 0; i < widget.updates.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(
              children: [
                if (_index == i)
                  const Icon(Icons.check, size: 18, color: AppColors.orange),
                const SizedBox(width: 10),
                Text(widget.updates[i]),
              ],
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.updates[_index],
            style: AppTypography.inter(
              AppColors.grayDark,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Icon(Icons.arrow_drop_down_rounded, color: AppColors.gray),
        ],
      ),
    );
  }
}
