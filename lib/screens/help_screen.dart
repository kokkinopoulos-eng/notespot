import 'package:flutter/material.dart';
import '../core/feature_flags.dart';
import '../l10n/app_localizations.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sections = _buildSections(l10n);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sections.length,
        separatorBuilder: (context, i) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, i) => sections[i],
      ),
    );
  }

  List<Widget> _buildSections(AppLocalizations l10n) {
    final items = [
      _HelpSection(
        icon: Icons.lightbulb_outline,
        title: l10n.helpSecIntroTitle,
        body: l10n.helpSecIntroBody,
      ),
      _HelpSection(
        icon: Icons.edit_note_outlined,
        title: l10n.helpSecEditorTitle,
        body: l10n.helpSecEditorBody,
      ),
      _HelpSection(
        icon: Icons.draw_outlined,
        title: l10n.helpSecHandwritingTitle,
        body: l10n.helpSecHandwritingBody,
      ),
      _HelpSection(
        icon: Icons.auto_awesome,
        title: l10n.helpSecEvaTitle,
        body: l10n.helpSecEvaBody,
      ),
      _HelpSection(
        icon: Icons.filter_list,
        title: l10n.helpSecFiltersTitle,
        body: l10n.helpSecFiltersBody,
      ),
      if (kCloudAiEnabled)
        _HelpSection(
          icon: Icons.workspace_premium_outlined,
          title: l10n.helpSecProTitle,
          body: l10n.helpSecProBody,
        ),
      _HelpSection(
        icon: Icons.backup_outlined,
        title: l10n.helpSecBackupTitle,
        body: l10n.helpSecBackupBody,
      ),
    ];
    return items;
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Icon(icon, size: 22),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          body,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55),
        ),
      ],
    );
  }
}
