import 'package:flutter/material.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  static const List<_ProductItem> _products = [
    _ProductItem(
      title: 'Laoo Market',
      description: 'ระบบหน้าร้านและจัดการการขาย',
      icon: Icons.storefront_outlined,
    ),
    _ProductItem(
      title: 'Laoo Meeting',
      description: 'ระบบแสดงและจัดการห้องประชุม',
      icon: Icons.meeting_room_outlined,
    ),
    _ProductItem(
      title: 'Laoo POS',
      description: 'ระบบขายหน้าร้านสำหรับหลายสาขา',
      icon: Icons.point_of_sale_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildHero(context)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              sliver: SliverToBoxAdapter(
                child: _buildProducts(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Text(
            'Laoo',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => _showComingSoon(context),
            icon: const Icon(Icons.login),
            label: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Text(
                'Laoo',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'จุดเริ่มต้นสำหรับระบบงานและผลิตภัณฑ์ของ Laoo Solutions',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.black54,
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProducts(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Products',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'ตัวอย่างระบบที่จะเปิดให้เข้าใช้งานในอนาคต',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 900
                    ? 3
                    : width >= 600
                        ? 2
                        : 1;
                const spacing = 16.0;
                final itemWidth =
                    (width - (spacing * (columns - 1))) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: _products
                      .map(
                        (product) => SizedBox(
                          width: itemWidth,
                          child: _ProductCard(
                            product: product,
                            onPressed: () => _showComingSoon(context),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Feature นี้จะพัฒนาในขั้นตอนถัดไป'),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onPressed,
  });

  final _ProductItem product;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                product.icon,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                product.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                product.description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black54,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 20),
              Text(
                'เปิดระบบ',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductItem {
  const _ProductItem({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}
