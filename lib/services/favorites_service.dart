import 'package:hive/hive.dart';
import '../models/post_model.dart';

class FavoritesService {
  static const String boxName = 'favoritesBox';

  Box<Post> get _box => Hive.box<Post>(boxName);

  /// Checks if a post with [id] is marked as favorite
  bool isFavorite(int id) {
    return _box.containsKey(id);
  }

  /// Toggles favorite status for [post].
  ///
  /// Note: We create a distinct copy of [Post] to adhere to Hive's rule that
  /// a HiveObject instance can only belong to one box at a time.
  Future<void> toggleFavorite(Post post) async {
    if (isFavorite(post.id)) {
      await _box.delete(post.id);
    } else {
      final copy = Post(
        id: post.id,
        title: post.title,
        body: post.body,
        userId: post.userId,
      );
      await _box.put(post.id, copy);
    }
  }

  /// Returns all stored favorite posts
  List<Post> getFavorites() {
    return _box.values.toList();
  }
}
