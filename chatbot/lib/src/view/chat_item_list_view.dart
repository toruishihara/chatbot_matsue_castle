import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:matsue_castle_chatbot/src/view/about_view.dart';
import 'package:matsue_castle_chatbot/src/view/shake_icon.dart';
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
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(buildSnackBar());
    });
  }

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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutView()),
              );
              break;
            case 1: // Help
              _showHelpDialog(context);
              break;
            case 2: // Settings
              Navigator.restorablePushNamed(context, SettingsView.routeName);
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'About'),
          NavigationDestination(icon: Icon(Icons.help_outline), label: 'Help'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  SnackBar buildSnackBar() {
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 0, 8, 60),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(2, 4),
            ),
          ],
        ),
        child: Row(
          children: const [
            Spacer(), // pushes text to the right
            Text(
              'マイクを押して日本語や、\n英語で話してください ↘︎',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(msg.text),
                    Text(isUser ? 'User' : 'Assistant',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
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
              labelText: 'Enter question text',
              border: const OutlineInputBorder(),
              suffixIcon: ShakeIcon(
                shake: chatViewModel.isRecording,
                onPressed: () {
                  if (kDebugMode) print("Mic pressed");
                  chatViewModel.handleMicButton();
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
          content: const Text('🎙️ Tap the microphone to ask by voice.\n\n'
              'You can talk in English or Japanese\n\n'
              'マイクボタンを押してから、日本語や英語で質問を話してください\n\n'),
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
