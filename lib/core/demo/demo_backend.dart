import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthState, PostgrestException;

/// In-memory stand-in for Supabase, used when the app runs with no keys.
/// It answers the same calls the screens make (from/select/eq/order/rpc...)
/// so every screen works with sample data and nothing leaves the device.
typedef DRow = Map<String, dynamic>;

const demoMe = 'demo-me';
const _other = 'demo-seller';

String _ago(int days, [int hours = 0]) => DateTime.now()
    .subtract(Duration(days: days, hours: hours))
    .toUtc()
    .toIso8601String();
String _soon(int days, [int hours = 0]) => DateTime.now()
    .add(Duration(days: days, hours: hours))
    .toUtc()
    .toIso8601String();

class DemoClient {
  DemoClient() {
    _seed();
  }

  final auth = _DemoAuth();
  final Map<String, List<DRow>> _t = {};
  int _n = 100;

  List<DRow> table(String name) =>
      _t.putIfAbsent(name == 'public_profiles' ? 'profiles' : name, () => []);

  dynamic from(String name) => _Query(this, name);

  DRow? find(String t, Object? id) {
    for (final r in table(t)) {
      if (r['id'] == id) return r;
    }
    return null;
  }

  String catName(Object? id) => (find('categories', id)?['name'] ?? '') as String;

  DRow add(String t, DRow d) {
    d.putIfAbsent('id', () => 'n${_n++}');
    d.putIfAbsent('created_at', () => DateTime.now().toUtc().toIso8601String());
    if (t == 'collection_requests') d.putIfAbsent('status', () => 'pending');
    if (t == 'products') d.putIfAbsent('status', () => 'active');
    table(t).add(d);
    return d;
  }

  void _points(int pts, String reason) {
    final row = table('user_points').first;
    row['balance'] = (row['balance'] as int) + pts;
    add('points_ledger', {'user_id': demoMe, 'points': pts, 'reason': reason});
  }

  /// Joins that PostgREST would do for 'select(*, categories(name))' etc.
  DRow embed(String t, DRow r) {
    final o = DRow.from(r);
    if (t == 'products') {
      o['categories'] = {'name': catName(r['category_id'])};
    } else if (t == 'collection_requests') {
      o['collection_request_items'] = [
        for (final i in table('collection_request_items'))
          if (i['request_id'] == r['id'])
            {
              ...i,
              'categories': {'name': catName(i['category_id'])},
            },
      ];
    } else if (t == 'cart_items') {
      o['products'] = find('products', r['product_id']);
    } else if (t == 'orders') {
      o['order_items'] = [
        for (final i in table('order_items'))
          if (i['order_id'] == r['id']) i,
      ];
    } else if (t == 'recycling_centres') {
      o['recycling_centre_categories'] = [
        for (final n in (r['cats'] as List))
          {
            'categories': {'name': n},
          },
      ];
    }
    return o;
  }

  Future<dynamic> rpc(String fn, {Map<String, dynamic>? params}) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final p = params ?? <String, dynamic>{};
    if (fn == 'accept_collection_request') {
      final r = find('collection_requests', p['p_request_id']);
      if (r != null) {
        r['status'] = 'accepted';
        r['vendor_id'] = demoMe;
      }
    } else if (fn == 'complete_collection_request') {
      final r = find('collection_requests', p['p_request_id']);
      if (r != null) {
        final kg = (p['p_weight_kg'] as num).toDouble();
        r['status'] = 'completed';
        r['actual_weight_kg'] = kg;
        r['price_per_kg'] = p['p_price_per_kg'];
        if (r['user_id'] == demoMe) _points((kg * 10).floor(), 'Pickup completed');
      }
    } else if (fn == 'update_order_status') {
      final o = find('orders', p['p_order_id']);
      if (o != null) o['status'] = p['p_status'];
    } else if (fn == 'redeem_reward') {
      final rw = find('rewards', p['p_reward_id']);
      if (rw == null) return null;
      final cost = rw['points_cost'] as int;
      if ((table('user_points').first['balance'] as int) < cost) {
        throw PostgrestException(message: 'Not enough points for this reward.');
      }
      _points(-cost, 'Redeemed: ${rw['title']}');
      if (rw['stock'] != null) rw['stock'] = (rw['stock'] as int) - 1;
    } else if (fn == 'place_orders_from_cart') {
      final cart = [
        for (final c in table('cart_items'))
          if (c['user_id'] == demoMe) c,
      ];
      if (cart.isEmpty) {
        throw PostgrestException(message: 'Your cart is empty.');
      }
      final bySeller = <Object?, List<DRow>>{};
      for (final c in cart) {
        final prod = find('products', c['product_id']);
        if (prod == null) continue;
        bySeller.putIfAbsent(prod['seller_id'], () => []).add({
          'prod': prod,
          'qty': c['quantity'],
        });
      }
      bySeller.forEach((seller, lines) {
        num total = 0;
        for (final l in lines) {
          total += (l['prod']['price'] as num) * (l['qty'] as num);
        }
        final order = add('orders', {
          'buyer_id': demoMe,
          'seller_id': seller,
          'status': 'placed',
          'total_amount': total,
          'fulfilment': p['p_fulfilment'],
          'delivery_address': p['p_address'],
          'note': p['p_note'],
        });
        for (final l in lines) {
          add('order_items', {
            'order_id': order['id'],
            'title': l['prod']['title'],
            'unit_price': l['prod']['price'],
            'quantity': l['qty'],
          });
        }
      });
      table('cart_items').removeWhere((c) => c['user_id'] == demoMe);
    }
    return null;
  }

  void _seed() {
    const cats = [
      'Plastic', 'Glass', 'Paper & Cardboard', 'Metal',
      'Electronics', 'Organic', 'Textiles',
    ];
    for (var i = 0; i < cats.length; i++) {
      add('categories', {'id': i + 1, 'name': cats[i]});
    }
    add('profiles', {
      'id': demoMe, 'role': 'vendor', 'full_name': 'Amara Okafor',
      'phone': '0803 000 0000', 'avatar_path': null,
    });
    add('profiles', {'id': _other, 'role': 'user', 'full_name': 'Kano Green Co.'});
    add('vendor_profiles', {
      'user_id': demoMe, 'business_name': 'Amara Recycling', 'status': 'approved',
      'phone': '0803 000 0000', 'service_area': 'Kano',
    });
    add('user_points', {'user_id': demoMe, 'balance': 340});
    for (final h in [
      [120, 'Pickup completed', 6], [50, 'Welcome bonus', 12], [170, 'Marketplace order', 3],
    ]) {
      add('points_ledger', {
        'user_id': demoMe, 'points': h[0], 'reason': h[1], 'created_at': _ago(h[2] as int),
      });
    }
    var rid = 1;
    for (final r in [
      ['₦500 airtime', 'Mobile airtime sent to your phone', 50, 'GreenSync', 200],
      ['Reusable tote bag', 'Durable bag made from recycled fabric', 120, 'EcoWear Kano', 50],
      ['₦2,000 grocery voucher', 'Use at partner supermarkets', 250, 'FreshMart', 40],
      ['Tree planting', 'We plant a tree in your name', 80, 'Green Kano Trust', null],
      ['Reusable water bottle', 'Stainless steel, 750 ml', 300, 'EcoWear Kano', 30],
      ['₦5,000 cash reward', 'Paid to your bank account', 600, 'GreenSync', 20],
    ]) {
      add('rewards', {
        'id': 'rw${rid++}', 'title': r[0], 'description': r[1], 'points_cost': r[2],
        'sponsor_name': r[3], 'stock': r[4], 'is_active': true,
      });
    }
    // title, category id, price, description, location, seller is me?
    const items = [
      ['Drip-glass table lamp', 2, 18500, 'Iridescent glass shade made from reclaimed bottle glass, on a black arched stand.', 'Sabon Gari', false],
      ['Patchwork denim tote', 7, 9500, 'Old jeans and jute stitched into a sturdy hand-finished tote.', 'Nasarawa', false],
      ['Recycled plastic planters (5-pack)', 1, 12000, 'Ten-inch planters moulded from recycled plastic, with drainage holes.', 'Kano Central', false],
      ['Daisy glass bottle with bamboo lid', 2, 3500, 'Reused glass bottle with daisy decals, bamboo lid and carry cord.', 'Sabon Gari', false],
      ['Polka-dot tin-can pen holder', 4, 1800, 'Upcycled tin can painted and wrapped in jute twine.', 'Kano Central', true],
      ['Tiered tin-can organiser', 4, 4200, 'Four decoupage cans joined into a desk organiser for pens and clips.', 'Kano Central', true],
      ['Frosted flower glass lamp', 2, 22000, 'Petal-shaped frosted shade on a brass-finish arm.', 'Sabon Gari', false],
      ['Fabric-scrap patchwork tote', 7, 7500, 'Colourful offcuts quilted into a roomy shopper.', 'Nasarawa', false],
      ['Vintage glass oil lamp', 2, 6500, 'Restored ribbed-glass table lamp with a brass burner.', 'Sabon Gari', false],
      ['Vintage book bundle (10)', 3, 5000, 'Pre-loved hardbacks sold by the stack. Mixed fiction, art and music.', 'Nasarawa', false],
      ['Fast-charger and Lightning cable', 5, 6000, 'Tested, cleaned and refurbished adaptor with cable.', 'Bompai', false],
      ['USB-C 20W charger set', 5, 8500, 'Refurbished 20W adaptor with USB-C to Lightning cable.', 'Bompai', true],
      ['Swing-lid recycled bin', 1, 4500, 'Household bin made from recycled plastic with a swing lid.', 'Kano Central', false],
      ['Wheeled recycling bin', 1, 25000, 'Large wheeled bin for sorting recyclables at home or on site.', 'Kano Central', true],
    ];
    for (var i = 0; i < items.length; i++) {
      final x = items[i];
      add('products', {
        'id': 'p$i', 'seller_id': x[5] == true ? demoMe : _other, 'category_id': x[1],
        'title': x[0], 'price': x[2], 'description': x[3], 'location': x[4],
        'unit': 'piece', 'quantity_available': 3 + i % 5, 'status': 'active',
        'image_asset': 'assets/demo/p$i.jpg', 'created_at': _ago(0, i * 5),
      });
    }
    add('orders', {
      'id': 'o1', 'buyer_id': demoMe, 'seller_id': _other, 'status': 'confirmed',
      'total_amount': 9500, 'fulfilment': 'pickup', 'created_at': _ago(4),
    });
    add('order_items', {'order_id': 'o1', 'title': 'Patchwork denim tote', 'unit_price': 9500, 'quantity': 1});
    add('orders', {
      'id': 'o2', 'buyer_id': _other, 'seller_id': demoMe, 'status': 'placed',
      'total_amount': 6000, 'fulfilment': 'delivery', 'delivery_address': '14 Ahmadu Bello Way, Kano',
      'created_at': _ago(0, 3),
    });
    add('order_items', {'order_id': 'o2', 'title': 'Polka-dot tin-can pen holder', 'unit_price': 1800, 'quantity': 2});
    add('order_items', {'order_id': 'o2', 'title': 'Tiered tin-can organiser', 'unit_price': 4200, 'quantity': 1});
    final reqs = <List<Object?>>[
      ['q1', demoMe, null, 'pending', _soon(1), '5 Gwarzo Road, Kano', 1, 12.0],
      ['q2', demoMe, _other, 'accepted', _soon(0, 5), '5 Gwarzo Road, Kano', 2, 6.0],
      ['q3', demoMe, _other, 'completed', _ago(9), '5 Gwarzo Road, Kano', 4, 8.5],
      ['q4', _other, null, 'pending', _soon(2), '22 Zoo Road, Kano', 5, 4.0],
      ['q5', _other, null, 'pending', _soon(1, 4), 'Sabon Gari Market Road', 3, 20.0],
      ['q6', _other, demoMe, 'accepted', _soon(0, 8), 'Bompai Industrial Estate', 1, 15.0],
    ];
    for (final q in reqs) {
      add('collection_requests', {
        'id': q[0], 'user_id': q[1], 'vendor_id': q[2], 'status': q[3],
        'scheduled_date': q[4], 'address': q[5], 'phone': '0803 000 0000',
        'notes': null, 'actual_weight_kg': q[3] == 'completed' ? q[7] : null,
        'price_per_kg': q[3] == 'completed' ? 120 : null,
      });
      add('collection_request_items', {
        'request_id': q[0], 'category_id': q[6], 'estimated_weight_kg': q[7], 'quantity': 1,
      });
    }
    for (final c in [
      ['Kano Central Recycling Hub', 'Zoo Road, Kano', '0803 000 0101', 'Accepts plastics, glass, paper and metal. Weighing and instant payment on site.', {'Mon-Fri': '8:00 - 17:00', 'Sat': '9:00 - 14:00'}, ['Plastic', 'Glass', 'Paper & Cardboard', 'Metal']],
      ['Sabon Gari Eco Point', 'Sabon Gari Market Road, Kano', '0803 000 0102', 'Community drop-off point for bottles, cans and cardboard.', {'Mon-Sat': '8:00 - 16:00'}, ['Plastic', 'Glass', 'Paper & Cardboard']],
      ['Bompai E-Waste Centre', 'Bompai Industrial Estate, Kano', '0803 000 0103', 'Safe collection of old phones, laptops, batteries and cables.', {'Mon-Fri': '9:00 - 16:00'}, ['Electronics', 'Metal']],
      ['Nasarawa Textile and Organic Hub', 'Nasarawa GRA, Kano', '0803 000 0104', 'Takes used clothing and kitchen or garden waste for composting.', {'Tue-Sat': '9:00 - 15:00'}, ['Textiles', 'Organic']],
    ]) {
      add('recycling_centres', {
        'name': c[0], 'address': c[1], 'phone': c[2], 'description': c[3],
        'operating_hours': c[4], 'cats': c[5], 'is_active': true,
      });
    }
    var k = 0;
    for (final a in [
      ['article', 'How to sort your waste at home', 'Keep three containers: one for plastics and metals, one for paper and cardboard, and one for organic waste.\n\nRinse bottles and cans before storing them. Clean material fetches a better price and is easier to recycle.', true],
      ['tip', 'Plastic bottles: remove the cap and flatten', 'Caps are often a different plastic from the bottle. Remove them, empty the bottle, and flatten it to save space.', false],
      ['article', 'What happens to your recyclables?', 'Collected material is sorted, cleaned and shredded or melted. Plastic becomes pellets, paper is pulped, glass is remoulded and metal is smelted.', false],
      ['tip', 'Turn kitchen waste into compost', 'Peels, vegetable scraps and garden leaves can be composted in a covered pit. Turn it every week and it becomes rich soil in about two months.', false],
      ['article', 'Why e-waste needs special care', 'Old phones, batteries and cables contain metals that are harmful if burned or dumped. Take them to an e-waste centre.', false],
    ]) {
      add('educational_resources', {
        'type': a[0], 'title': a[1], 'body': a[2], 'author_name': 'GreenSync Team',
        'is_featured': a[3], 'is_published': true, 'created_at': _ago(k++),
      });
    }
  }
}

class _DemoUser {
  final id = demoMe;
  final email = 'amara@greensync.demo';
}

/// Always "signed in" as the demo user. Anything else (sign up, reset
/// password...) is accepted and ignored.
class _DemoAuth {
  final _DemoUser _u = _DemoUser();
  Object? get currentSession => _u;
  _DemoUser get currentUser => _u;
  Stream<AuthState> get onAuthStateChange => const Stream<AuthState>.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<dynamic>.value(null);
}

int _cmp(dynamic a, dynamic b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  if (a is bool) return (a ? 1 : 0) - ((b as bool) ? 1 : 0);
  if (a is num && b is num) return a.compareTo(b);
  return a.toString().compareTo(b.toString());
}

/// One query, built up by chaining and run when awaited.
class _Query implements Future<dynamic> {
  _Query(this.db, this.table);

  final DemoClient db;
  final String table;
  String _op = 'select';
  Object? _data;
  String? _key;
  bool _selectAfter = false, _single = false, _maybe = false;
  int? _limit;
  final _filters = <bool Function(DRow)>[];
  final _orders = <(String, bool)>[];

  _Query select([String? columns]) {
    if (_op != 'select') _selectAfter = true;
    return this;
  }

  _Query insert(Object data) { _op = 'insert'; _data = data; return this; }
  _Query update(Map<String, dynamic> data) { _op = 'update'; _data = data; return this; }
  _Query delete() { _op = 'delete'; return this; }
  _Query upsert(Map<String, dynamic> data, {String? onConflict}) {
    _op = 'upsert'; _data = data; _key = onConflict; return this;
  }
  _Query eq(String c, Object? v) { _filters.add((r) => r[c] == v); return this; }
  _Query neq(String c, Object? v) { _filters.add((r) => r[c] != v); return this; }
  _Query inFilter(String c, List<dynamic> v) { _filters.add((r) => v.contains(r[c])); return this; }
  _Query order(String c, {bool ascending = true}) { _orders.add((c, ascending)); return this; }
  _Query limit(int n) { _limit = n; return this; }
  _Query single() { _single = true; return this; }
  _Query maybeSingle() { _maybe = true; return this; }

  Future<dynamic> _run() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final rows = db.table(table);
    bool match(DRow r) => _filters.every((f) => f(r));
    List<DRow> out;
    if (_op == 'insert') {
      final list = _data is List ? _data as List : [_data];
      out = [for (final d in list) db.add(table, DRow.from(d as Map))];
    } else if (_op == 'update') {
      out = rows.where(match).toList();
      for (final r in out) {
        r.addAll(DRow.from(_data as Map));
      }
    } else if (_op == 'delete') {
      out = rows.where(match).toList();
      rows.removeWhere(match);
    } else if (_op == 'upsert') {
      final d = DRow.from(_data as Map);
      final keys = (_key ?? 'id').split(',');
      DRow? hit;
      for (final r in rows) {
        if (keys.every((k) => r[k] == d[k])) { hit = r; break; }
      }
      if (hit != null) {
        hit.addAll(d);
        out = [hit];
      } else {
        out = [db.add(table, d)];
      }
    } else {
      out = rows.where(match).toList();
    }
    if (_orders.isNotEmpty) {
      out.sort((x, y) {
        for (final o in _orders) {
          final c = _cmp(x[o.$1], y[o.$1]);
          if (c != 0) return o.$2 ? c : -c;
        }
        return 0;
      });
    }
    if (_limit != null && out.length > _limit!) out = out.sublist(0, _limit!);
    final List<DRow> res = [for (final r in out) db.embed(table, r)];
    if (_single || _maybe) {
      if (res.isEmpty) {
        if (_maybe) return null;
        throw PostgrestException(message: 'No matching row found.');
      }
      return res.first;
    }
    if (_op != 'select' && !_selectAfter) return null;
    return res;
  }

  Future<dynamic> get _f => Future<dynamic>.sync(_run);

  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue, {Function? onError}) =>
      _f.then(onValue, onError: onError);
  @override
  Future<dynamic> catchError(Function onError, {bool Function(Object error)? test}) =>
      _f.catchError(onError, test: test);
  @override
  Future<dynamic> whenComplete(FutureOr<void> Function() action) => _f.whenComplete(action);
  @override
  Stream<dynamic> asStream() => _f.asStream();
  @override
  Future<dynamic> timeout(Duration timeLimit, {FutureOr<dynamic> Function()? onTimeout}) =>
      _f.timeout(timeLimit, onTimeout: onTimeout);
}
