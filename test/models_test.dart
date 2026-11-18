import 'package:flutter_test/flutter_test.dart';
import 'package:hive_posts_app/models/data.dart';
import 'package:hive_posts_app/models/post_model.dart';

void main() {
  group('Part 1 - Data Model Tests', () {
    test('Data model instantiates correctly with required fields', () {
      final data = Data(name: 'Paul', id: '1');
      expect(data.name, 'Paul');
      expect(data.id, '1');
    });

    test('DataAdapter has correct typeId', () {
      final adapter = DataAdapter();
      expect(adapter.typeId, 1);
    });
  });

  group('Part 2 - Post Model Tests', () {
    test('Post model instantiates correctly', () {
      final post = Post(
        id: 101,
        title: 'Lab 5 Title',
        body: 'Lab 5 Body content',
        userId: 42,
      );

      expect(post.id, 101);
      expect(post.title, 'Lab 5 Title');
      expect(post.body, 'Lab 5 Body content');
      expect(post.userId, 42);
    });

    test('Post.fromJson parses JSONPlaceholder format correctly', () {
      final json = {
        'userId': 1,
        'id': 1,
        'title': 'sunt aut facere repellat',
        'body': 'quia et suscipit suscipit recusandae',
      };

      final post = Post.fromJson(json);

      expect(post.id, 1);
      expect(post.userId, 1);
      expect(post.title, 'sunt aut facere repellat');
      expect(post.body, 'quia et suscipit suscipit recusandae');
    });

    test('PostAdapter has correct typeId', () {
      final adapter = PostAdapter();
      expect(adapter.typeId, 0);
    });
  });
}
