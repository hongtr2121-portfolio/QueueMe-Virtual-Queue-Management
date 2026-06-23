import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:queueapp/api/restaurant_service.dart';
import 'package:queueapp/core/error_mapper.dart';
import 'package:queueapp/models/restaurant.dart';
import 'package:queueapp/api/nominatim_service.dart';


class AdminStoreScreen extends StatefulWidget {
  const AdminStoreScreen({super.key});

  @override
  State<AdminStoreScreen> createState() => _AdminStoreScreenState();
}

class _AdminStoreScreenState extends State<AdminStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _svc = RestaurantService();
  final _storage = const FlutterSecureStorage();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _fromTimeCtrl = TextEditingController();
  final _toTimeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _nominatim = NominatimService();

  int? _adminUserId;
  bool _loadingAdmin = true;
  bool _saving = false;

  /// Nhà hàng hiện tại của admin (nếu đã có)
  Restaurant? _existingRestaurant;

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  /// Khởi tạo màn hình:
  /// 1) lấy userId admin
  /// 2) load draft local (email/phone/from/to)
  /// 3) load store từ backend (theo admin hiện tại) để prefill
  Future<void> _initScreen() async {
    final rawId = await _storage.read(key: 'userId');
    final id = int.tryParse(rawId ?? '');

    // gán adminUserId trước để dùng cho load store
    if (mounted) {
      setState(() {
        _adminUserId = id;
      });
    }

    // 2) load draft local (email/phone/open time)
    await _loadLocalDraft();

    // 3) load store từ backend (nếu biết admin id)
    if (id != null) {
      await _loadStoreFromBackend(id);
    }

    if (!mounted) return;
    setState(() {
      _loadingAdmin = false;
    });

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không lấy được adminUserId. Hãy đăng nhập lại.'),
        ),
      );
    }
  }

  /// Đọc email / phone / from / to đã lưu trong SecureStorage
  Future<void> _loadLocalDraft() async {
    final email = await _storage.read(key: 'store_email');
    final phone = await _storage.read(key: 'store_phone');
    final from = await _storage.read(key: 'store_from_time');
    final to = await _storage.read(key: 'store_to_time');

    if (!mounted) return;
    setState(() {
      _emailCtrl.text = email ?? '';
      _phoneCtrl.text = phone ?? '';
      _fromTimeCtrl.text = from ?? '';
      _toTimeCtrl.text = to ?? '';
    });
  }

  /// Lấy nhà hàng của admin hiện tại từ backend → prefill form
  Future<void> _loadStoreFromBackend(int adminId) async {
    try {
      final list = await _svc.getRestaurants(page: 1, pageSize: 100);
      // 1 admin ~ 1 store → lọc theo adminUserID
      final mine = list.where((r) => r.adminUserID == adminId).toList();
      if (mine.isEmpty) return;

      final r = mine.first;
      _existingRestaurant = r;

      // parse OperatingHours: "HH:mm - HH:mm"
      String? from;
      String? to;
      if (r.operatingHours != null && r.operatingHours!.contains('-')) {
        final parts = r.operatingHours!.split('-');
        if (parts.length >= 2) {
          from = parts[0].trim();
          to = parts[1].trim();
        }
      }

      if (!mounted) return;
      setState(() {
        _nameCtrl.text = r.name;
        _addressCtrl.text = r.address ?? '';

        // chỉ fill nếu ô đang trống (ưu tiên draft local nếu có)
        if (_fromTimeCtrl.text.isEmpty && (from ?? '').isNotEmpty) {
          _fromTimeCtrl.text = from!;
        }
        if (_toTimeCtrl.text.isEmpty && (to ?? '').isNotEmpty) {
          _toTimeCtrl.text = to!;
        }
      });
    } catch (e) {
      debugPrint('loadStoreFromBackend error: $e');
      // không cần show lỗi to, cho màn hình vẫn dùng được
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _fromTimeCtrl.dispose();
    _toTimeCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
    );
    if (picked != null) {
      controller.text =
      '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _onSubmit() async {
    if (_adminUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thiếu adminUserId – vui lòng đăng nhập lại.'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final name = _nameCtrl.text.trim();
      final address = _addressCtrl.text.trim();
      final from = _fromTimeCtrl.text.trim();
      final to = _toTimeCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      // ✅ ADD: geocode address -> latitude/longitude
      double? latitude;
      double? longitude;

      if (address.isNotEmpty) {
        final geo = await _nominatim.geocodeAddress(address);

        if (geo == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không định vị được địa chỉ. Vui lòng kiểm tra lại.')),
          );
          return; // sẽ nhảy xuống finally và tắt _saving
        }

        latitude = double.tryParse(geo['lat']?.toString() ?? '');
        longitude = double.tryParse(geo['lon']?.toString() ?? '');

        if (latitude == null || longitude == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không đọc được vĩ độ/kinh độ từ địa chỉ.')),
          );
          return;
        }
      }

      String? operatingHours;
      if (from.isNotEmpty && to.isNotEmpty) {
        operatingHours = '$from - $to';
      }

      // Lưu thêm local: email / phone / from / to
      await _storage.write(
          key: 'store_email', value: email.isEmpty ? null : email);
      await _storage.write(
          key: 'store_phone', value: phone.isEmpty ? null : phone);
      await _storage.write(
          key: 'store_from_time', value: from.isEmpty ? null : from);
      await _storage.write(
          key: 'store_to_time', value: to.isEmpty ? null : to);

      // === TẠO MỚI HAY UPDATE? ===
      if (_existingRestaurant == null ||
          _existingRestaurant!.restaurantID == null) {
        // ❇️ CHƯA CÓ STORE → TẠO MỚI
        final created = await _svc.create(
          name: name,
          address: address.isEmpty ? null : address,
          operatingHours: operatingHours,
          overallRating: null,
          adminUserId: _adminUserId,
          latitude: latitude,
          longitude: longitude,
        );

        _existingRestaurant = created;
      } else {
        // ✏️ ĐÃ CÓ STORE → UPDATE
        final updated = Restaurant(
          restaurantID: _existingRestaurant!.restaurantID,
          name: name,
          address: address.isEmpty ? null : address,
          latitude: latitude ?? _existingRestaurant!.latitude,
          longitude: longitude ?? _existingRestaurant!.longitude,
          googlePlaceID: _existingRestaurant!.googlePlaceID,
          overallRating: _existingRestaurant!.overallRating,
          operatingHours: operatingHours,
          adminUserID: _adminUserId,
        );

        await _svc.updateRestaurant(
          _existingRestaurant!.restaurantID!,
          updated,
        );

        _existingRestaurant = updated;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thông tin nhà hàng.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapError(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFFFC928);
    const bg = Color(0xFFFFF7DC);
    const green = Color(0xFF2EAD4B);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: yellow,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: _loadingAdmin
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              'Add Store',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white,
                child: Icon(Icons.store_mall_directory,
                    size: 36, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Store name'),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _inputDecoration(),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Tên nhà hàng không được để trống';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text('Email'),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration()
                            .copyWith(hintText: 'haidilao.vhm@gmail.com'),
                      ),
                      const SizedBox(height: 14),
                      const Text('Phone number'),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecoration().copyWith(
                            hintText: '(+84) 943 696 205'),
                      ),
                      const SizedBox(height: 14),
                      const Text('Open time'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _fromTimeCtrl,
                              readOnly: true,
                              decoration:
                              _inputDecoration().copyWith(
                                hintText: 'From',
                              ),
                              onTap: () => _pickTime(_fromTimeCtrl),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _toTimeCtrl,
                              readOnly: true,
                              decoration:
                              _inputDecoration().copyWith(
                                hintText: 'To',
                              ),
                              onTap: () => _pickTime(_toTimeCtrl),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text('Address'),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _addressCtrl,
                        maxLines: 3,
                        decoration: _inputDecoration().copyWith(
                          hintText:
                          'Tầng 4 Vạn Hạnh Mall, 11 Sư Vạn Hạnh, Quận 10, TP.HCM',
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: green,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 2,
                          ),
                          onPressed: (_saving || _adminUserId == null)
                              ? null
                              : _onSubmit,
                          child: _saving
                              ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                              AlwaysStoppedAnimation(
                                  Colors.white),
                            ),
                          )
                              : const Text(
                            'Confirm',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }
}
