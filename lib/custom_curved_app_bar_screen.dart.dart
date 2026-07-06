import 'package:flutter/material.dart';

class CustomCurvedAppBarScreen extends StatelessWidget {
  const CustomCurvedAppBarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bodyColor,
      appBar: CustomCornerAppBar(
        title: 'Categories',
        height: 150,
        curveDepth: 30,
        curveRadius: 30,
        reverseCurve: true,
        onBackTap: () {
          Navigator.of(context).maybePop();
        },
        actions: const [
          HeaderBadgeButton(
            icon: Icons.favorite_border,
            count: 0,
          ),
          SizedBox(width: 10),
          HeaderBadgeButton(
            icon: Icons.shopping_cart_outlined,
            count: 0,
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        itemCount: categoryItems.length,
        separatorBuilder: (context, index) {
          return const SizedBox(height: 14);
        },
        itemBuilder: (context, index) {
          final item = categoryItems[index];

          return CategoryCard(
            item: item,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductScreen(title: item.title),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ProductScreen extends StatelessWidget {
  final String title;

  const ProductScreen({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bodyColor,
      appBar: CustomCornerAppBar(
        title: title,
        height: 150,
        reverseCurve: false,
        curveDepth: 30,
        curveRadius: 30,
        onBackTap: () {
          Navigator.of(context).maybePop();
        },
        actions: const [
          HeaderBadgeButton(
            icon: Icons.favorite_border,
            count: 0,
          ),
          SizedBox(width: 10),
          HeaderBadgeButton(
            icon: Icons.shopping_cart_outlined,
            count: 0,
          ),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 24),
        child: Column(
          children: [
            SortFilterBox(),
            Expanded(
              child: EmptyProductsView(),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomCornerAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final double height;
  final bool reverseCurve;
  final double curveDepth;
  final double curveRadius;
  final VoidCallback? onBackTap;
  final List<Widget> actions;
  final List<Color> gradientColors;

  const CustomCornerAppBar({
    super.key,
    required this.title,
    this.height = 170,
    this.reverseCurve = true,
    this.curveDepth = 42,
    this.curveRadius = 46,
    this.onBackTap,
    this.actions = const [],
    this.gradientColors = const [
      Color(0xFFFF2A1A),
      Color(0xFFFF8200),
      Color(0xFFFFD735),
    ],
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ClipPath(
        clipper: reverseCurve
            ? ReverseBodyCornerClipper(
                depth: curveDepth,
                radius: curveRadius,
              )
            : RoundedBottomAppBarClipper(radius: curveRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: gradientColors,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  HeaderCircleButton(
                    icon: Icons.arrow_back_ios_new,
                    onTap: onBackTap,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReverseBodyCornerClipper extends CustomClipper<Path> {
  final double depth;
  final double radius;

  const ReverseBodyCornerClipper({
    required this.depth,
    required this.radius,
  });

  @override
  Path getClip(Size size) {
    final safeDepth = depth.clamp(0.0, size.height);
    final safeRadius = radius.clamp(0.0, size.width / 2);
    final bodyTopY = size.height - safeDepth;

    return Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height)
      ..quadraticBezierTo(0, bodyTopY, safeRadius, bodyTopY)
      ..lineTo(size.width - safeRadius, bodyTopY)
      ..quadraticBezierTo(size.width, bodyTopY, size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant ReverseBodyCornerClipper oldClipper) {
    return oldClipper.depth != depth || oldClipper.radius != radius;
  }
}

class RoundedBottomAppBarClipper extends CustomClipper<Path> {
  final double radius;

  const RoundedBottomAppBarClipper({
    required this.radius,
  });

  @override
  Path getClip(Size size) {
    final safeRadius = radius.clamp(0.0, size.width / 2);

    return Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height - safeRadius)
      ..quadraticBezierTo(0, size.height, safeRadius, size.height)
      ..lineTo(size.width - safeRadius, size.height)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width,
        size.height - safeRadius,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant RoundedBottomAppBarClipper oldClipper) {
    return oldClipper.radius != radius;
  }
}

class HeaderCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const HeaderCircleButton({
    super.key,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class HeaderBadgeButton extends StatelessWidget {
  final IconData icon;
  final int count;

  const HeaderBadgeButton({
    super.key,
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
        ),
        Positioned(
          top: -6,
          right: -3,
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFF4D7D),
              shape: BoxShape.circle,
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CategoryInfo {
  final String title;
  final int productCount;
  final IconData? icon;

  const CategoryInfo({
    required this.title,
    required this.productCount,
    this.icon,
  });
}

const List<CategoryInfo> categoryItems = [
  CategoryInfo(
    title: 'Beauty & Health',
    productCount: 1,
    icon: null,
  ),
  CategoryInfo(
    title: 'Beauty & Personal Care',
    productCount: 1,
    icon: Icons.spa,
  ),
  CategoryInfo(
    title: 'Cosmetic',
    productCount: 0,
    icon: Icons.brush,
  ),
  CategoryInfo(
    title: 'Fragrances',
    productCount: 0,
    icon: Icons.local_florist,
  ),
  CategoryInfo(
    title: "Girls' Cosmetic",
    productCount: 0,
    icon: null,
  ),
  CategoryInfo(
    title: 'Grooming & Wellness',
    productCount: 0,
    icon: null,
  ),
  CategoryInfo(
    title: 'Health Food Supplement',
    productCount: 0,
    icon: null,
  ),
  CategoryInfo(
    title: 'Personal Care',
    productCount: 0,
    icon: Icons.spa,
  ),
];

class CategoryCard extends StatelessWidget {
  final CategoryInfo item;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF090806),
                child: item.icon == null
                    ? null
                    : Icon(
                        item.icon,
                        color: Colors.white70,
                        size: 26,
                      ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${item.productCount} Products',
                      style: const TextStyle(
                        color: Color(0xFF9D9993),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF8A867F),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SortFilterBox extends StatelessWidget {
  const SortFilterBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.tune,
            color: Colors.white,
            size: 26,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Name (A-Z)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white70,
            size: 32,
          ),
        ],
      ),
    );
  }
}

class EmptyProductsView extends StatelessWidget {
  const EmptyProductsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -70),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              color: Color(0xFF6F6D72),
              size: 74,
            ),
            SizedBox(height: 24),
            Text(
              'No products found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 18),
            Text(
              'Try another keyword to discover matching products.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFA5A09B),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppColors {
  static const Color bodyColor = Color(0xFF0E0C09);
  static const Color cardColor = Color(0xFF211E1A);
}
