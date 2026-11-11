import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'firebase_options.dart';

const String kShopName = 'Meo shop';
const Color kBrand = Color(0xFFE8456B);
const Color kBrand2 = Color(0xFFFF8A5B);
const Color kBg = Color(0xFFFBF7F6);
const int kLowStock = 10;

CollectionReference<Map<String, dynamic>> get productsCol =>
    FirebaseFirestore.instance.collection('products');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

// ---------------- Tiện ích ----------------
String formatMoney(num v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '$buf đ';
}

class Product {
  final String id;
  final String name;
  final num price;
  final int soluong;
  final String image;
  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.soluong,
    required this.image,
  });

  factory Product.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return Product(
      id: d.id,
      name: (m['name'] ?? '').toString(),
      price: (m['price'] as num?) ?? 0,
      soluong: (m['soluong'] as num?)?.toInt() ?? 0,
      image: (m['image'] ?? '').toString(),
    );
  }
}

InputDecoration inputDeco(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    );

// ---------------- App ----------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kShopName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kBrand),
        useMaterial3: true,
        scaffoldBackgroundColor: kBg,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return snap.hasData ? const ProductListPage() : const LoginPage();
        },
      ),
    );
  }
}

// ---------------- Logo ----------------
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 36});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [kBrand, kBrand2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(Icons.pets, color: Colors.white, size: size * 0.55),
    );
  }
}

// ---------------- Hiển thị ảnh (base64 hoặc link) ----------------
class _ImagePlaceholder extends StatelessWidget {
  final IconData icon;
  const _ImagePlaceholder({this.icon = Icons.image_outlined});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBrand.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(icon, color: kBrand.withValues(alpha: 0.4), size: 32),
    );
  }
}

Widget buildImage(String data) {
  if (data.isEmpty) return const _ImagePlaceholder();
  if (data.startsWith('http')) {
    return Image.network(data,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const _ImagePlaceholder(icon: Icons.broken_image_outlined));
  }
  try {
    return Image.memory(base64Decode(data),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            const _ImagePlaceholder(icon: Icons.broken_image_outlined));
  } catch (_) {
    return const _ImagePlaceholder(icon: Icons.broken_image_outlined);
  }
}

class ProductImage extends StatelessWidget {
  final String data;
  final double size;
  const ProductImage({super.key, required this.data, this.size = 56});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: size, height: size, child: buildImage(data)),
    );
  }
}

class StockBadge extends StatelessWidget {
  final int soluong;
  final bool solid;
  const StockBadge({super.key, required this.soluong, this.solid = false});
  @override
  Widget build(BuildContext context) {
    final Color color;
    final String text;
    if (soluong <= 0) {
      color = Colors.red;
      text = 'Hết hàng';
    } else if (soluong <= kLowStock) {
      color = Colors.orange.shade800;
      text = 'Sắp hết: $soluong';
    } else {
      color = Colors.green.shade700;
      text = 'Còn $soluong';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              color: solid ? Colors.white : color,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ---------------- Menu sửa / xóa ----------------
class _ProductMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool overlay;
  const _ProductMenu(
      {required this.onEdit, required this.onDelete, this.overlay = false});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Tùy chọn',
      onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 20),
            SizedBox(width: 10),
            Text('Sửa'),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 20, color: Colors.red),
            SizedBox(width: 10),
            Text('Xóa', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
      child: overlay
          ? Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_vert, size: 18),
            )
          : null,
    );
  }
}

// ---------------- Đăng nhập ----------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _hide = true;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = 'Đăng nhập thất bại (${e.code})');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kBrand, kBrand2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandLogo(size: 68),
                      const SizedBox(height: 14),
                      const Text(kShopName,
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: kBrand)),
                      const SizedBox(height: 4),
                      Text('Đăng nhập quản trị cửa hàng',
                          style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: inputDeco('Email', Icons.email_outlined),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _pass,
                        obscureText: _hide,
                        onSubmitted: (_) => _login(),
                        decoration:
                            inputDeco('Mật khẩu', Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_hide
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => setState(() => _hide = !_hide),
                          ),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                        ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Đăng nhập',
                                  style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Banner ----------------
class _BannerData {
  final String tag;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  const _BannerData(this.tag, this.title, this.subtitle, this.icon, this.colors);
}

class ShopBanner extends StatefulWidget {
  const ShopBanner({super.key});
  @override
  State<ShopBanner> createState() => _ShopBannerState();
}

class _ShopBannerState extends State<ShopBanner> {
  static const _slides = [
    _BannerData(
      'MEO SHOP',
      'Thời trang xịn,\ngiá mê ly',
      'Bộ sưu tập mới cập nhật mỗi tuần',
      Icons.checkroom,
      [kBrand, kBrand2],
    ),
    _BannerData(
      'ƯU ĐÃI',
      'Sắm đồ thả ga,\nkhông lo về giá',
      'Nhiều ưu đãi hấp dẫn mỗi ngày',
      Icons.local_offer,
      [Color(0xFF6C4BDB), Color(0xFFE8456B)],
    ),
    _BannerData(
      'CHÍNH HÃNG',
      'Chất lượng thật,\nphục vụ tận tâm',
      'Mèo luôn sẵn sàng hỗ trợ bạn',
      Icons.verified,
      [Color(0xFF0FA3A3), Color(0xFF4C8DF6)],
    ),
  ];

  final _ctrl = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_ctrl.hasClients) return;
      final next = (_page + 1) % _slides.length;
      _ctrl.animateToPage(next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 600;
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: compact ? 170 : 240,
          child: Stack(
            children: [
              PageView.builder(
                controller: _ctrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) =>
                    _BannerSlide(data: _slides[i], compact: compact),
              ),
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < _slides.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: i == _page ? 22 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: i == _page ? 1 : 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _BannerSlide extends StatelessWidget {
  final _BannerData data;
  final bool compact;
  const _BannerSlide({required this.data, required this.compact});

  Widget _circle(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: data.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(right: -50, top: -50, child: _circle(200, 0.12)),
          Positioned(left: -40, bottom: -70, child: _circle(170, 0.10)),
          Positioned(
            right: compact ? 14 : 60,
            top: 0,
            bottom: 0,
            child: Center(
              child: Icon(data.icon,
                  size: compact ? 90 : 150,
                  color: Colors.white.withValues(alpha: 0.28)),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: compact ? 20 : 40, vertical: compact ? 16 : 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(data.tag,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2)),
                ),
                SizedBox(height: compact ? 8 : 14),
                Text(data.title,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 22 : 34,
                        height: 1.15,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: compact ? 6 : 10),
                Text(data.subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: compact ? 13 : 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Danh sách sản phẩm ----------------
const _sortLabels = [
  'Mặc định',
  'Giá tăng dần',
  'Giá giảm dần',
  'Tên A → Z',
  'Số lượng ít nhất',
];

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});
  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  String _keyword = '';
  int _sort = 0;
  bool _lowOnly = false;
  bool _grid = true;

  void _toast(String msg) {
    final wide = MediaQuery.of(context).size.width > 500;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        width: wide ? 360 : null,
      ));
  }

  Future<void> _openForm([Product? p]) async {
    final saved = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => ProductFormPage(product: p)));
    if (saved == true) _toast(p == null ? 'Đã thêm sản phẩm' : 'Đã cập nhật');
  }

  Future<void> _delete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.delete_forever, color: Colors.red, size: 36),
        title: const Text('Xóa sản phẩm'),
        content: Text('Bạn có chắc muốn xóa "${p.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (ok == true) {
      await productsCol.doc(p.id).delete();
      _toast('Đã xóa "${p.name}"');
    }
  }

  void _showDetail(Product p) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                  child: AspectRatio(
                      aspectRatio: 1, child: buildImage(p.image)),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(formatMoney(p.price),
                          style: const TextStyle(
                              fontSize: 22,
                              color: kBrand,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      StockBadge(soluong: p.soluong),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Đóng')),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _openForm(p);
                            },
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Sửa'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Product> _apply(List<Product> all) {
    final list = all
        .where((p) => p.name.toLowerCase().contains(_keyword))
        .where((p) => !_lowOnly || p.soluong <= kLowStock)
        .toList();
    switch (_sort) {
      case 1:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 2:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 3:
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 4:
        list.sort((a, b) => a.soluong.compareTo(b.soluong));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final width = MediaQuery.of(context).size.width;
    final wide = width >= 800;
    final side = math.max(16.0, (width - 1200) / 2);

    SliverPadding pad(Widget sliver) => SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: side), sliver: sliver);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 16,
        title: const Row(
          children: [
            BrandLogo(size: 36),
            SizedBox(width: 10),
            Text(kShopName,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: kBrand,
                    letterSpacing: 0.3)),
          ],
        ),
        actions: [
          if (wide)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.person, size: 18),
                label: Text(email),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kBrand,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm sản phẩm'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: productsCol.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Lỗi: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!.docs.map(Product.fromDoc).toList();
          final shown = _apply(all);

          final totalQty = all.fold<int>(0, (s, p) => s + p.soluong);
          final totalValue =
              all.fold<num>(0, (s, p) => s + p.price * p.soluong);
          final lowCount = all.where((p) => p.soluong <= kLowStock).length;

          return CustomScrollView(
            slivers: [
              pad(const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: ShopBanner(),
                ),
              )),
              pad(SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child:
                      _buildStats(all.length, totalQty, totalValue, lowCount),
                ),
              )),
              pad(SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 22, bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Danh sách sản phẩm',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: kBrand.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('${shown.length}/${all.length}',
                                style: const TextStyle(
                                    color: kBrand,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildToolbar(wide),
                    ],
                  ),
                ),
              )),
              if (shown.isEmpty)
                pad(SliverToBoxAdapter(child: _buildEmpty(all.isEmpty)))
              else if (_grid)
                pad(SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: width < 600 ? 280 : 250,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _gridCard(shown[i]),
                    childCount: shown.length,
                  ),
                ))
              else
                pad(SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _listCard(shown[i]),
                    childCount: shown.length,
                  ),
                )),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 110),
                  child: Column(
                    children: [
                      const BrandLogo(size: 28),
                      const SizedBox(height: 8),
                      Text('$kShopName - Mua sắm vui vẻ mỗi ngày',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStats(int count, int qty, num value, int low) {
    final items = [
      _StatData(Icons.category_rounded, 'Sản phẩm', '$count', kBrand),
      _StatData(Icons.layers_rounded, 'Tổng số lượng', '$qty',
          const Color(0xFF0FA3A3)),
      _StatData(Icons.payments_rounded, 'Giá trị tồn kho', formatMoney(value),
          const Color(0xFF6C4BDB)),
      _StatData(Icons.warning_amber_rounded, 'Sắp hết hàng', '$low',
          Colors.orange.shade800),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 800 ? 4 : 2;
      final w = (c.maxWidth - 12 * (cols - 1)) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items
            .map((d) => SizedBox(width: w, child: _StatCard(data: d)))
            .toList(),
      );
    });
  }

  Widget _buildToolbar(bool wide) {
    final search = TextField(
      decoration: inputDeco('Tìm sản phẩm theo tên', Icons.search)
          .copyWith(isDense: true),
      onChanged: (v) => setState(() => _keyword = v.toLowerCase().trim()),
    );

    final sort = PopupMenuButton<int>(
      tooltip: 'Sắp xếp',
      initialValue: _sort,
      onSelected: (v) => setState(() => _sort = v),
      itemBuilder: (_) => [
        for (int i = 0; i < _sortLabels.length; i++)
          PopupMenuItem(value: i, child: Text(_sortLabels[i])),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 18),
            const SizedBox(width: 6),
            Text(_sort == 0 ? 'Sắp xếp' : _sortLabels[_sort]),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );

    final filter = FilterChip(
      avatar: const Icon(Icons.warning_amber_rounded, size: 18),
      label: const Text('Sắp hết hàng'),
      selected: _lowOnly,
      onSelected: (v) => setState(() => _lowOnly = v),
    );

    final view = SegmentedButton<bool>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(value: true, icon: Icon(Icons.grid_view_rounded)),
        ButtonSegment(value: false, icon: Icon(Icons.view_list_rounded)),
      ],
      selected: {_grid},
      onSelectionChanged: (s) => setState(() => _grid = s.first),
    );

    if (wide) {
      return Row(
        children: [
          Expanded(child: search),
          const SizedBox(width: 12),
          sort,
          const SizedBox(width: 12),
          filter,
          const SizedBox(width: 12),
          view,
        ],
      );
    }
    return Column(
      children: [
        search,
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              sort,
              const SizedBox(width: 10),
              filter,
              const SizedBox(width: 10),
              view,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(bool noData) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets, size: 64, color: kBrand.withValues(alpha: 0.35)),
            const SizedBox(height: 12),
            Text(
              noData
                  ? 'Meo shop chưa có sản phẩm nào'
                  : 'Không tìm thấy sản phẩm phù hợp',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            if (noData) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Thêm sản phẩm đầu tiên'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _gridCard(Product p) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        onTap: () => _showDetail(p),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  buildImage(p.image),
                  if (p.soluong <= kLowStock)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: StockBadge(soluong: p.soluong, solid: true),
                    ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: _ProductMenu(
                      overlay: true,
                      onEdit: () => _openForm(p),
                      onDelete: () => _delete(p),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(formatMoney(p.price),
                      style: const TextStyle(
                          color: kBrand,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('Kho: ${p.soluong}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listCard(Product p) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onTap: () => _showDetail(p),
        leading: ProductImage(data: p.image, size: 60),
        title: Text(p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(formatMoney(p.price),
                  style: const TextStyle(
                      color: kBrand, fontWeight: FontWeight.w800)),
              StockBadge(soluong: p.soluong),
            ],
          ),
        ),
        trailing: _ProductMenu(
          onEdit: () => _openForm(p),
          onDelete: () => _delete(p),
        ),
      ),
    );
  }
}

class _StatData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  _StatData(this.icon, this.label, this.value, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon, color: data.color, size: 22),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(data.value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

// ---------------- Form thêm / sửa ----------------
class ProductFormPage extends StatefulWidget {
  final Product? product;
  const ProductFormPage({super.key, this.product});
  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _soluong;
  String _image = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _price = TextEditingController(text: p != null ? '${p.price.round()}' : '');
    _soluong = TextEditingController(text: p != null ? '${p.soluong}' : '');
    _image = p?.image ?? '';
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 600, imageQuality: 60);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final b64 = base64Encode(bytes);
    if (b64.length > 800000) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ảnh quá lớn, vui lòng chọn ảnh nhỏ hơn')));
      return;
    }
    setState(() => _image = b64);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'name': _name.text.trim(),
      'price': num.parse(_price.text.trim()),
      'soluong': int.parse(_soluong.text.trim()),
      'image': _image,
    };
    try {
      if (widget.product == null) {
        await productsCol.add(data);
      } else {
        await productsCol.doc(widget.product!.id).update(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi lưu dữ liệu: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(isEdit ? 'Sửa sản phẩm' : 'Thêm sản phẩm',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: SizedBox(
                            width: 180,
                            height: 180,
                            child: buildImage(_image),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                            _image.isEmpty ? 'Chọn hình ảnh' : 'Đổi hình ảnh'),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _name,
                        decoration:
                            inputDeco('Tên sản phẩm', Icons.label_outline),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Nhập tên sản phẩm'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _price,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: inputDeco(
                            'Giá sản phẩm (đ)', Icons.attach_money_rounded),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nhập giá sản phẩm'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _soluong,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration:
                            inputDeco('Số lượng', Icons.inventory_outlined),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nhập số lượng'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48)),
                              child: const Text('Hủy'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _saving ? null : _save,
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48)),
                              child: Text(_saving ? 'Đang lưu...' : 'Lưu'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}