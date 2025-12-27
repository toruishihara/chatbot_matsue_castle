import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About App'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Application Icon (optional)
              // Image.asset('assets/icon/matsue_castle_icon.png', height: 100, width: 100),
              const SizedBox(height: 24),

              // Application Name
              Text(
                'Matue Castle Chatbot',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Application Version
              Text(
                'Version 1.0.0', // Replace with dynamic version
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Application Legalese (Copyright)
              Text(
                '© 2025 Toru Ishihara. All rights reserved.', // Replace with actual legalese
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Referenced Document Titles (mimicking your previous request)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Left align this section
                children: <Widget>[
                  Text(
                    '参照文献:',
                    style: Theme.of(context).textTheme.titleSmall,
                    // textAlign removed, now inherits from parent Column
                  ),
                  const SizedBox(height: 8),
                  Text('・A Guidebook to Mastue Castle and its Vicinities in English 松江市観光グッドウィルガイド連絡会'),
                  Text('・堀尾氏ゆかりの城館を辿る【研究テーマ：城郭】堀尾吉晴公共同研究会'),
                  Text('・松江城の石垣刻印について 松江市歴史まちづくり部史料調査課長／飯塚康行／2022 年 2 月 10 日記'),
                  Text('・松江城築城に使われた石材の産地について 松江市ホームページ'),
                  Text('・松江城の石垣の石材とその起源（島根大学地球資源環境学研究報告, 2016）'),
                  Text('・城歩き編 国宝天守に行こう松江城 加藤理文（かとうまさふみ）先生'),
                  Text('・Wikipedia 松江城、日本の城、その他関連項目'),
                ],
              ),              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
