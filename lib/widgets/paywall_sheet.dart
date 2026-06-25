import 'package:flutter/material.dart';
import '../services/ai_settings_service.dart';

class PaywallSheet extends StatefulWidget {
  const PaywallSheet({super.key});

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  final TextEditingController _keyController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = "";
  AiProvider _selectedProvider = AiProvider.gemini;

  void _handleValidation() async {
    setState(() => _isLoading = true);
    final result = await testApiKey(_selectedProvider, _keyController.text);
    setState(() {
      _statusMessage = result.message;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(controller: _keyController, decoration: const InputDecoration(labelText: "API Key")),
        const SizedBox(height: 20),
        if (_isLoading)
          const CircularProgressIndicator()
        else
          ElevatedButton(onPressed: _handleValidation, child: const Text("Επαλήθευση")),
        if (_statusMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _statusMessage,
              style: TextStyle(color: _statusMessage.contains("✅") ? Colors.green : Colors.red),
            ),
          ),
      ],
    );
  }
}