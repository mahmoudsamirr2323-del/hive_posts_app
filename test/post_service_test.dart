import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_posts_app/models/post_model.dart';
import 'package:hive_posts_app/services/post_service.dart';

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  final int statusCode;
  final String body;

  _FakeHttpClientRequest({required this.statusCode, required this.body});

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool persistentConnection = true;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future addStream(Stream<List<int>> stream) async => await stream.drain();

  @override
  void add(List<int> data) {}

  @override
  Future<HttpClientResponse> close() async =>
      _FakeHttpClientResponse(statusCode: statusCode, body: body);
}

class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  final int statusCode;
  final String body;

  _FakeHttpClientResponse({required this.statusCode, required this.body});

  @override
  bool get persistentConnection => false;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  String get reasonPhrase => 'OK';

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  int get contentLength => utf8.encode(body).length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(utf8.encode(body)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name.toLowerCase()] = [value.toString()];
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }

  @override
  List<String>? operator [](String name) => _headers[name.toLowerCase()];

  @override
  String? value(String name) => _headers[name.toLowerCase()]?.first;
}

class _TestHttpOverrides extends HttpOverrides {
  int statusCode = 200;
  String body = '[]';
  bool throwError = false;

  _TestHttpOverrides();

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient(
      statusCode: statusCode,
      body: body,
      throwError: throwError,
    );
  }
}

class _FakeHttpClient extends Fake implements HttpClient {
  final int statusCode;
  final String body;
  final bool throwError;

  _FakeHttpClient({
    required this.statusCode,
    required this.body,
    required this.throwError,
  });

  @override
  bool autoUncompress = true;

  @override
  Duration? connectionTimeout;

  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  int? maxConnectionsPerHost;

  @override
  String? userAgent;

  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (throwError) {
      throw const SocketException('Simulated network offline');
    }
    return _FakeHttpClientRequest(statusCode: statusCode, body: body);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => openUrl('GET', url);
}

void main() {
  late Directory tempDir;
  late Box<Post> postsBox;
  late PostService postService;
  late _TestHttpOverrides testHttpOverrides;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_post_service_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PostAdapter());
    }
    postsBox = await Hive.openBox<Post>('postsBox');
    postService = PostService();
    testHttpOverrides = _TestHttpOverrides();
    HttpOverrides.global = testHttpOverrides;
  });

  tearDown(() async {
    HttpOverrides.global = null;
    await postsBox.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PostService End-to-End Fallback & HTTP Handling Tests', () {
    test('Successful 200 response caches to Hive and returns online posts',
        () async {
      testHttpOverrides.statusCode = 200;
      testHttpOverrides.body = jsonEncode([
        {
          'id': 1,
          'title': 'Online Post 1',
          'body': 'Content 1',
          'userId': 1,
        },
        {
          'id': 2,
          'title': 'Online Post 2',
          'body': 'Content 2',
          'userId': 1,
        },
      ]);

      final posts = await postService.getPosts();

      expect(posts.length, 2);
      expect(posts.first.title, 'Online Post 1');
      expect(postsBox.length, 2);
      expect(postsBox.getAt(0)?.title, 'Online Post 1');
    });

    test('Non-200 HTTP response falls back to cached Hive posts', () async {
      // Pre-populate cache
      await postsBox.add(
        Post(id: 10, title: 'Cached Post', body: 'Cached Body', userId: 1),
      );

      // Simulate 500 Server Error
      testHttpOverrides.statusCode = 500;
      testHttpOverrides.body = 'Internal Server Error';

      final posts = await postService.getPosts();

      expect(posts.length, 1);
      expect(posts.first.title, 'Cached Post');
    });

    test('Network failure (SocketException) falls back to cached Hive posts',
        () async {
      // Pre-populate cache
      await postsBox.add(
        Post(id: 20, title: 'Airplane Cache', body: 'Offline Body', userId: 2),
      );

      // Simulate Airplane mode
      testHttpOverrides.throwError = true;

      final posts = await postService.getPosts();

      expect(posts.length, 1);
      expect(posts.first.title, 'Airplane Cache');
    });

    test(
        'Network failure with empty cache throws "No Internet and No Cached Data"',
        () async {
      await postsBox.clear();
      testHttpOverrides.throwError = true;

      expect(
        () async => await postService.getPosts(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No Internet and No Cached Data'),
          ),
        ),
      );
    });

    test(
        'Non-200 status with empty cache throws "No Internet and No Cached Data"',
        () async {
      await postsBox.clear();
      testHttpOverrides.statusCode = 404;
      testHttpOverrides.body = 'Not Found';

      expect(
        () async => await postService.getPosts(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No Internet and No Cached Data'),
          ),
        ),
      );
    });
  });
}
