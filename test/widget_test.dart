import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_posts_app/models/post_model.dart';
import 'package:hive_posts_app/screens/favorites_screen.dart';
import 'package:hive_posts_app/screens/posts_screen.dart';
import 'package:hive_posts_app/services/favorites_service.dart';
import 'package:hive_posts_app/services/post_service.dart';

class FakePostService extends Fake implements PostService {
  final List<Post> samplePosts;

  FakePostService({this.samplePosts = const []});

  @override
  Future<List<Post>> getPosts() async {
    return samplePosts;
  }
}

void main() {
  late Directory tempDir;
  late FavoritesService favoritesService;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_widget_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PostAdapter());
    }
    await Hive.openBox<Post>('postsBox');
    await Hive.openBox<Post>('favoritesBox');
    favoritesService = FavoritesService();
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  testWidgets('PostsScreen renders AppBar with title and favorites action',
      (WidgetTester tester) async {
    final fakeService = FakePostService(
      samplePosts: [
        Post(id: 1, title: 'Sample Title', body: 'Sample Body', userId: 1),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PostsScreen(
          service: fakeService,
          favoritesService: favoritesService,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Posts'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.text('Sample Title'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('FavoritesScreen shows "No favorites yet" when box is empty',
      (WidgetTester tester) async {
    final favBox = Hive.box<Post>('favoritesBox');
    await tester.runAsync(() async {
      await favBox.clear();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: FavoritesScreen(
          favoritesService: favoritesService,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Favorite Posts'), findsOneWidget);
    expect(find.text('No favorites yet'), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsOneWidget);
  });

  testWidgets('FavoritesScreen displays cards when favorites exist',
      (WidgetTester tester) async {
    final favBox = Hive.box<Post>('favoritesBox');
    final post = Post(
      id: 99,
      title: 'Test Favorite Post',
      body: 'This is the body of the test favorite post',
      userId: 1,
    );
    await tester.runAsync(() async {
      await favBox.put(99, post);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: FavoritesScreen(
          favoritesService: favoritesService,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Test Favorite Post'), findsOneWidget);
    expect(find.text('99'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);

    // Clean up
    await tester.runAsync(() async {
      await favBox.clear();
    });
  });
}
