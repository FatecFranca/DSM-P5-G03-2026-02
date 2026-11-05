import 'package:flutter/material.dart';

/// Mantém a ação visível e anuncia mudanças de carregamento sem duplicar a
/// leitura do conteúdo visual do botão.
class LoadingButtonContent extends StatelessWidget {
  const LoadingButtonContent({
    super.key,
    required this.label,
    required this.loading,
    required this.loadingLabel,
    this.icon,
    this.progressColor,
  });

  final String label;
  final bool loading;
  final String loadingLabel;
  final IconData? icon;
  final Color? progressColor;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: loading,
    label: loading ? '$label. $loadingLabel.' : label,
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: progressColor,
              ),
            )
          else if (icon != null)
            Icon(icon),
          if (loading || icon != null) const SizedBox(width: 8),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    ),
  );
}

/// Texto de estado dinâmico anunciado educadamente por leitores de tela.
class LiveRegionText extends StatelessWidget {
  const LiveRegionText(this.message, {super.key, this.style, this.textAlign});

  final String message;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: message,
    child: ExcludeSemantics(
      child: Text(message, style: style, textAlign: textAlign),
    ),
  );
}
