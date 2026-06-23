import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:queueapp/api/review_service.dart';
import 'package:queueapp/core/error_mapper.dart';
import 'package:queueapp/models/restaurant_review.dart';

class RestaurantReviewScreen extends StatefulWidget {
  final int restaurantId;
  final String restaurantName;
  final int queueEntryId;

  const RestaurantReviewScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.queueEntryId, // ✅ ADD



  });

  @override
  State<RestaurantReviewScreen> createState() => _RestaurantReviewScreenState();
}

class _RestaurantReviewScreenState extends State<RestaurantReviewScreen> {
  final _svc = ReviewService();
  final _storage = const FlutterSecureStorage();
  final _commentCtrl = TextEditingController();

  int _rating = 0; // 0 = chưa chọn
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn chọn số sao trước nha.')),
      );
      return;
    }

    final rawUserId = await _storage.read(key: 'userId');
    final userId = int.tryParse(rawUserId ?? '');
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không lấy được userId.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final comment = _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim();

      // ✅ gọi đúng theo ReviewService hiện tại (match backend DTO)
      await _svc.createReview(
        restaurantId: widget.restaurantId,
        userId: userId,
        rating: _rating,
        comment: comment,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cảm ơn bạn đã đánh giá!')),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
            (route) => false, // xoá hết stack cũ
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapError(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }


  Widget _star(int i) {
    final filled = i <= _rating;
    return IconButton(
      onPressed: _submitting ? null : () => setState(() => _rating = i),
      icon: Icon(
        filled ? Icons.star : Icons.star_border,
        size: 34,
        color: filled ? const Color(0xFFFFC928) : Colors.black26,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFF7DC);
    const yellow = Color(0xFFFFC928);
    const green = Color(0xFF2EAD4B);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: yellow,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'RATE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.restaurantName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text('Trải nghiệm của bạn như thế nào?'),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [for (int i = 1; i <= 5; i++) _star(i)],
              ),

              const SizedBox(height: 16),
              const Text('Nhận xét (tuỳ chọn)'),
              const SizedBox(height: 6),
              TextField(
                controller: _commentCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Ví dụ: phục vụ nhanh, nhân viên dễ thương...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                      : const Text(
                    'Submit',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
