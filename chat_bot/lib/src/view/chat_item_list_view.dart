import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/chat_message.dart';
import '../settings/settings_view.dart';
import '../view_model/chat_view_model.dart';

/// Displays a list of ChatItems.
class ChatItemListView extends StatelessWidget {
  const ChatItemListView({
    super.key,
  });

  static const routeName = '/';

  @override
  Widget build(BuildContext context) {
    Provider.of<ChatViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sample Items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to the settings page. If the user leaves and returns
              // to the app after it has been killed while running in the
              // background, the navigation stack is restored.
              Navigator.restorablePushNamed(context, SettingsView.routeName);
            },
          ),
        ],
      ),
      body: buildChatColumn(context)
    );
  }

  Widget buildChatColumn(BuildContext context) {
    final chatViewModel = Provider.of<ChatViewModel>(context);
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
              labelText: 'Enter text',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.mic),
                onPressed: () {
                  if (kDebugMode) {
                    print("Mic pressed");
                  }
                  final vm = context.read<ChatViewModel>();
                  vm.handleMicButton();
                },
              ),
            ),
            onSubmitted: (value) async {
              if (value.trim().isEmpty) return;
              // read your ViewModel
              final vm = context.read<ChatViewModel>();
              // await the async function
              await vm.sendMessage(value.trim());
            },
          ),
        ),
      ],
    );
  }
}
