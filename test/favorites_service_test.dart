import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_posts_app/models/post_model.dart';
import 'package:hive_posts_app/services/favorites_service.dart';

void main() {
  late Directory tempDir;
  late FavoritesService favoritesService;
  late Box<Post> favBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_favorites_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PostAdapter());
    }
    favBox = await Hive.openBox<Post>(FavoritesService.boxName);
    favoritesService = FavoritesService();
  });

  tearDown(() async {
    await favBox.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FavoritesService Tests', () {
    test('isFavorite returns false for unstored post', () {
      expect(favoritesService.isFavorite(999), isFalse);
    });

    test('toggleFavorite adds post to favorites and uses post id as key', () async {
      final post = Post(
        id: 42,
        title: 'Quantum Computing',
        body: 'Introduction to Qubits',
        userId: 1,
      );

      await favoritesService.toggleFavorite(post);

      expect(favoritesService.isFavorite(42), isTrue);
      expect(favBox.containsKey(42), isTrue);
      expect(favoritesService.getFavorites().length, 1);
      expect(favoritesService.getFavorites().first.title, 'Quantum Computing');
    });

    test('toggleFavorite removes already favorited post', () async {
      final post = Post(
        id: 7,
        title: 'Cloud Native',
        body: 'Microservices & Containers',
        userId: 2,
      );

      await favoritesService.toggleFavorite(post);
      expect(favoritesService.isFavorite(7), isTrue);

      await favoritesService.toggleFavorite(post);
      expect(favoritesService.isFavorite(7), isFalse);
      expect(favoritesService.getFavorites(), isEmpty);
    });

    test('Saving favorite clones post and avoids HiveObject single-box conflict', () async {
      // Simulate post existing in another box (e.g. postsBox)
      final postsBox = await Hive.openBox<Post>('postsBox');
      final originalPost = Post(
        id: 15,
        title: 'Original Cached Post',
        body: 'Inside postsBox',
        userId: 3,
      );
      await postsBox.put(15, originalPost);
      expect(originalPost.isInBox, isTrue);

      // Toggle favorite should not throw HiveError because it copies the post
      await favoritesService.toggleFavorite(originalPost);
      expect(favoritesService.isFavorite(15), isTrue);

      final favPost = favBox.get(15);
      expect(favPost, isNotNull);
      expect(favPost!.id, 15);
      expect(favPost.title, 'Original Cached Post');

      // The favorite copy is in favBox, while originalPost remains in postsBox
      expect(favPost.box?.name.toLowerCase(), FavoritesService.boxName.toLowerCase());
      expect(originalPost.box?.name.toLowerCase(), 'postsbox');

      await postsBox.close();
    });
  });
}
