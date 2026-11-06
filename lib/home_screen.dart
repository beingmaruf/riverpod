import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpodd/home_controller.dart';
import 'package:flutter_riverpodd/post_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('HomeScreen build function called');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen'),
      ),
      body: Column(
        children: [
          /// Counter value
          Consumer(
            builder: (context, ref, child) {
              final int count = ref.watch(counterProvider);

              return Center(
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 40,
                  ),
                ),
              );
            },
          ),

          /// Counter buttons
          Consumer(
            builder: (context, ref, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton(
                    onPressed: () {
                      ref.read(counterProvider.notifier).decrement();
                    },
                    child: const Text('-'),
                  ),
                  const SizedBox(width: 20),
                  FilledButton(
                    onPressed: () {
                      ref.read(counterProvider.notifier).increment();
                    },
                    child: const Text('+'),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          /// Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Toggle'),
              const SizedBox(width: 20),
              Consumer(
                builder: (context, ref, child) {
                  final bool isToggled = ref.watch(toggleProvider);

                  return Switch(
                    value: isToggled,
                    onChanged: (bool value) {
                      ref.read(toggleProvider.notifier).changeValue(value);
                    },
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Consumer(builder: (context, ref, child) {
              final String selectedFruit = ref.watch(selectedFruitProvider);
              return DropdownMenu<String>(
                  width: double.infinity,
                  label: const Text('Select Fruit'),
                  initialSelection: selectedFruit,
                  dropdownMenuEntries: fruitDropdownItems.map((String fruit) {
                    return DropdownMenuEntry(
                      value: fruit,
                      label: fruit,
                    );
                  }).toList(),
                  onSelected: (String? value) {
                    ref.read(selectedFruitProvider.notifier).changeFruit(value);
                  });
            }),
          ),

          /// Posts list
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final AsyncValue<List<PostModel>> postsLoadState =
                    ref.watch(postsProvider);

                return postsLoadState.when(
                  // skipLoadingOnReload: true,
                  // skipLoadingOnRefresh: true,
                  // skipError: false,
                  loading: () {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                  error: (error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            getErrorMessage(error),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () {
                              ref
                                  .read(
                                    postsProvider.notifier,
                                  )
                                  .refreshPosts();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  },
                  data: (List<PostModel> posts) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        await ref.read(postsProvider.notifier).refreshPosts();
                      },
                      child: ListView.separated(
                        itemCount: posts.length,
                        separatorBuilder: (context, index) {
                          return const Divider(
                            height: 1,
                          );
                        },
                        itemBuilder: (context, index) {
                          final PostModel post = posts[index];

                          return ListTile(
                            title: Text(post.title),
                            subtitle: Text(post.body),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
