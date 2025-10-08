import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/chat_message.dart';
import '../settings/settings_view.dart';
import '../view_model/chat_view_model.dart';

class ChatItemListView extends StatefulWidget {
  const ChatItemListView({super.key});
  static const routeName = '/';

  @override
  State<ChatItemListView> createState() => _ChatItemListViewState();
}

class _ChatItemListViewState extends State<ChatItemListView> {
  int _selectedIndex = 0; // for the bottom bar

  @override
  Widget build(BuildContext context) {
    Provider.of<ChatViewModel>(context); // keep for rebuilds if you want

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matsue Castle Chatbot'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () =>
                Navigator.restorablePushNamed(context, SettingsView.routeName),
          ),
        ],
      ),
      body: buildChatColumn(context),

      // ---- Bottom 3-button bar (Material 3) ----
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) async {
          setState(() => _selectedIndex = i);
          switch (i) {
            case 0: // About
              showAboutDialog(
                context: context,
                applicationName: 'Matsue Castle Chatbot',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2025 Toru Ishihara',
              );
              break;
            case 1: // Help
              _showHelpDialog(context);
              /*
              showModalBottomSheet(
                context: context,
                showDragHandle: true,
                builder: (_) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Help\n\n1) マイクで質問\n2) テキストで質問\n3) 左上の戻るで閉じる',
                  ),
                ),
              );
              */
              break;
            case 2: // Settings
              Navigator.restorablePushNamed(context, SettingsView.routeName);
              break;
          }
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.info_outline), label: 'About'),
          NavigationDestination(
              icon: Icon(Icons.help_outline), label: 'Help'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget buildChatColumn(BuildContext context) {
    final chatViewModel = context.watch<ChatViewModel>();
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: chatViewModel.messages.length,
            itemBuilder: (context, index) {
              final msg = chatViewModel.messages[index];
              final isUser = msg.role == ChatRole.user;
              return Align(
                alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment:
                      isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(msg.text),
                    Text(isUser ? 'User' : 'Assistant',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Enter text',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.mic),
                onPressed: () {
                  if (kDebugMode) print("Mic pressed");
                  context.read<ChatViewModel>().handleMicButton();
                },
              ),
            ),
            onSubmitted: (value) async {
              if (value.trim().isEmpty) return;
              await context.read<ChatViewModel>().sendMessage(value.trim());
            },
          ),
        ),
      ],
    );
  }

    /// Show Help dialog
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Help & Tips'),
          content: const Text(
            '🗣️ You can talk or type to the bot about Matsue Castle.\n\n'
            '🎙️ Tap the microphone to ask by voice.\n\n'
            '⚙️ You can change settings in the top-right menu.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
