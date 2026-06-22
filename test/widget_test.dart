import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_riverpodd/home_controller.dart';
import 'package:flutter_riverpodd/home_screen.dart';
import 'package:flutter_riverpodd/post_model.dart';

class TestPostsController extends PostsController {
  @override
  Future<List<PostModel>> build() async {
    return <PostModel>[
      const PostModel(
        userId: 1,
        id: 1,
        title: 'Test title',
        body: 'Test body',
      ),
    ];
  }
}

void main() {
  testWidgets('Home screen should build', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: ProviderScope(
          overrides: [
            postsProvider.overrideWith(TestPostsController.new),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      ),
    );

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
