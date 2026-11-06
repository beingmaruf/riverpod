import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpodd/post_model.dart';
import 'package:flutter_riverpodd/network_client.dart';

// Notifier          + NotifierProvider
// AsyncNotifier     + AsyncNotifierProvider

// Riverpod-এর official documentation-ও বলে NotifierProvider একটি Notifier(Controller)-কে expose করে এবং AsyncNotifierProvider একটি AsyncNotifier(Controller)-কে expose করে।

// Provider, Controller ke UI er kache expose kore. UI theke amra provider ke access kore controller er method call korte pari. Provider er maddhome amra controller er state keo access korte pari.

// Notifier = normal controller

// NotifierProvider = normal controller কে UI তে use করার দরজা


// AsyncNotifier = API/async controller

// AsyncNotifierProvider = API/async controller কে UI তে use করার দরজা

/// ------------------------------------------------------------
/// COUNTER CONTROLLER + PROVIDER
/// ------------------------------------------------------------

final counterProvider = NotifierProvider<CounterController, int>(
  CounterController.new,
);

class CounterController extends Notifier<int> {
  @override
  int build() {
    // Counter-এর initial value
    return 0;
  }

  void increment() {
    state++;
  }

  void decrement() {
    if (state > 0) {
      state--;
    }
  }
}

/// ------------------------------------------------------------
/// TOGGLE CONTROLLER + PROVIDER
/// ------------------------------------------------------------

final toggleProvider = NotifierProvider<ToggleController, bool>(
  ToggleController.new,
);

class ToggleController extends Notifier<bool> {
  @override
  bool build() {
    // Toggle-এর initial value
    return false;
  }

  void changeValue(bool value) {
    state = value;
  }
}

/// ------------------------------------------------------------
/// POSTS PROVIDER
/// ------------------------------------------------------------

final NetworkClient _networkClient = NetworkClient(
  baseUrl: 'https://jsonplaceholder.typicode.com',
  onUnauthorized: () {},
  enableLogger: true,
);

// final postsProvider = FutureProvider<List<PostModel>>((ref) async {
//   return fetchPosts();
// });

final postsProvider = AsyncNotifierProvider<PostsController, List<PostModel>>(
  PostsController.new,
);

class PostsController extends AsyncNotifier<List<PostModel>> {
  @override
  Future<List<PostModel>> build() async {
    try {
      return await fetchPosts();
    } catch (error) {
      _logFetchError(error);
      rethrow;
    }
  }

  /// ------------------------------------------------------------
  /// GET POSTS API
  /// ------------------------------------------------------------

  Future<List<PostModel>> fetchPosts() async {
    final NetworkResponse response = await _networkClient.getRequest(
      '/posts',
      requiresAuth: false,
    );

    if (!response.isSuccess) {
      throw Exception(
        response.errorMessage ?? 'Failed to load posts',
      );
    }

    final dynamic responseBody =
        response.responseData?['data'] ?? response.responseData;

    if (responseBody is! List) {
      throw Exception('Invalid posts response');
    }

    return responseBody
        .whereType<Map<String, dynamic>>()
        .map(PostModel.fromJson)
        .toList();
  }

  void _logFetchError(Object error) {
    debugPrint(
      'Failed to fetch posts: $error',
    );
  }

  /// ------------------------------------------------------------
  /// REFRESH POSTS
  /// ------------------------------------------------------------

  Future<void> refreshPosts() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      return fetchPosts();
    });
  }
}

/// ------------------------------------------------------------
/// DROPDOWN CONTROLLER + PROVIDER
/// ------------------------------------------------------------

List<String> fruitDropdownItems = [
  'Apple',
  'Banana',
  'Cherry',
  'Orange',
  'Mango',
];

final selectedFruitProvider = NotifierProvider<SelectedFruitController, String>(
  SelectedFruitController.new,
);

class SelectedFruitController extends Notifier<String> {
  @override
  String build() {
    return fruitDropdownItems.first;
  }

  void changeFruit(String? value) {
    if (value == null) {
      return;
    }
    state = value;
  }
}

/// ------------------------------------------------------------
/// ERROR MESSAGE
/// ------------------------------------------------------------

String getErrorMessage(Object error) {
  if (error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException) {
    return 'No internet connection';
  }

  if (error is Exception) {
    final String message = error.toString();

    return message.replaceFirst(
      'Exception: ',
      '',
    );
  }

  return error.toString();
}
