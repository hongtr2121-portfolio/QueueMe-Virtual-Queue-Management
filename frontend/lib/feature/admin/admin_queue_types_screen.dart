import 'package:flutter/material.dart';
import 'package:queueapp/api/queue_type_service.dart';
import 'package:queueapp/models/queue_type.dart';

class AdminQueueTypesScreen extends StatefulWidget {
  final int restaurantID;

  const AdminQueueTypesScreen({
    super.key,
    required this.restaurantID,
  });

  @override
  State<AdminQueueTypesScreen> createState() => _AdminQueueTypesScreenState();
}

class _AdminQueueTypesScreenState extends State<AdminQueueTypesScreen> {
  final _queueTypeService = QueueTypeService();

  bool _isLoading = true;
  bool _isError = false;
  List<QueueType> _queueTypes = [];

  @override
  void initState() {
    super.initState();
    _loadQueueTypes();
  }

  Future<void> _loadQueueTypes() async {
    setState(() {
      _isLoading = true;
      _isError = false;
    });
    try {
      final items = await _queueTypeService.getByRestaurant(widget.restaurantID);
      setState(() {
        _queueTypes = items;
      });
    } catch (e) {
      debugPrint('getByRestaurant error: $e');
      setState(() => _isError = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi khi tải queue types')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5D9),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFFFC928),
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
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Queue Type List',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _buildBody(),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                _openQueueTypeForm(mode: _FormMode.add);
              },
              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
              label: const Text(
                'Add new queue type',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_isError) {
      return Center(
        child: TextButton(
          onPressed: _loadQueueTypes,
          child: const Text('Thử tải lại'),
        ),
      );
    }
    if (_queueTypes.isEmpty) {
      return const Center(
        child: Text('Chưa có queue type nào.\nNhấn "Add new queue type" để tạo.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQueueTypes,
      child: ListView.builder(
        itemCount: _queueTypes.length,
        itemBuilder: (context, index) {
          final qt = _queueTypes[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _QueueTypeCard(
              queueType: qt,
              onEdit: () {
                _openQueueTypeForm(
                  mode: _FormMode.edit,
                  existing: qt,
                  index: index,
                );
              },
              onDelete: () {
                _confirmDelete(index);
              },
              onToggleStatus: () async {
                try {
                  final updated =
                  await _queueTypeService.toggleStatus(qt.queueTypeID);
                  if (updated == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Không đổi được trạng thái'),
                        ),
                      );
                    }
                    return;
                  }
                  setState(() {
                    _queueTypes[index] = updated;
                  });
                } catch (e) {
                  debugPrint('toggleStatus error: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Không đổi được trạng thái')),
                    );
                  }
                }
              },
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(int index) async {
    final qt = _queueTypes[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xoá loại bàn này?'),
          content: Text('Bạn chắc chắn muốn xoá "${qt.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xoá'),
            ),
          ],
        );
      },
    );

    if (ok == true) {
      try {
        final okApi =
        await _queueTypeService.deleteQueueType(qt.queueTypeID);
        if (!okApi) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không xoá được queue type')),
            );
          }
          return;
        }

        setState(() {
          _queueTypes.removeAt(index);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xoá queue type')),
          );
        }
      } catch (e) {
        debugPrint('deleteQueueType error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không xoá được queue type')),
          );
        }
      }
    }
  }

  Future<void> _openQueueTypeForm({
    required _FormMode mode,
    QueueType? existing,
    int? index,
  }) async {
    final result = await Navigator.push<_QueueTypeFormResult>(
      context,
      MaterialPageRoute(
        builder: (_) => QueueTypeFormScreen(
          mode: mode,
          existing: existing,
        ),
      ),
    );

    if (result == null) return;

    try {
      if (mode == _FormMode.add) {
        final created = await _queueTypeService.createQueueType(
          restaurantID: widget.restaurantID,
          name: result.name,
          maxPartySize: result.maxPartySize,
          durationMinutes: result.durationMinutes,
          isActive: result.isActive,
        );
        if (created == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tạo queue type thất bại')),
            );
          }
          return;
        }
        setState(() {
          _queueTypes.add(created);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã tạo queue type mới')),
          );
        }
      } else if (mode == _FormMode.edit &&
          existing != null &&
          index != null) {
        final updated = await _queueTypeService.updateQueueType(
          queueTypeID: existing.queueTypeID,
          name: result.name,
          maxPartySize: result.maxPartySize,
          durationMinutes: result.durationMinutes,
          isActive: result.isActive,
        );
        if (updated == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cập nhật queue type thất bại')),
            );
          }
          return;
        }
        setState(() {
          _queueTypes[index] = updated;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã cập nhật queue type')),
          );
        }
      }
    } catch (e) {
      debugPrint('create/update queue type error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lưu queue type thất bại')),
        );
      }
    }
  }
}

class _QueueTypeCard extends StatelessWidget {
  final QueueType queueType;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  const _QueueTypeCard({
    required this.queueType,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = queueType.isActive;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            offset: const Offset(0, 3),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.orangeAccent,
            child: const Icon(Icons.table_restaurant, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  queueType.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tối đa: ${queueType.maxPartySize} khách\n'
                      'Thời lượng phục vụ: ${queueType.standardServiceDuration} phút/bàn',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Status: ',
                      style: TextStyle(fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: onToggleStatus,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.green.withOpacity(0.15)
                              : Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onEdit,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text(
                          'Edit',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onDelete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(fontSize: 13, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ----- FORM RESULT + MODE -----

enum _FormMode { add, edit }

class _QueueTypeFormResult {
  final String name;
  final int maxPartySize;
  final int durationMinutes;
  final bool isActive;

  _QueueTypeFormResult({
    required this.name,
    required this.maxPartySize,
    required this.durationMinutes,
    required this.isActive,
  });
}

/// ----- QUEUE TYPE FORM PAGE (thay cho bottom sheet) -----

class QueueTypeFormScreen extends StatefulWidget {
  final _FormMode mode;
  final QueueType? existing;

  const QueueTypeFormScreen({
    super.key,
    required this.mode,
    this.existing,
  });

  @override
  State<QueueTypeFormScreen> createState() => _QueueTypeFormScreenState();
}

class _QueueTypeFormScreenState extends State<QueueTypeFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // 🔽 các option tên queue type cho dropdown
  final List<String> _queueTypeNameOptions = [
    'Bàn 2 khách',
    'Bàn 4 khách',
    'Bàn 6 khách',
    'Bàn 8 khách',
    'Phòng VIP',
  ];

  String? _selectedName;
  late TextEditingController _maxPartyController;
  late TextEditingController _durationController;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    // nếu đang edit mà tên hiện tại không có trong list option → thêm vào đầu
    if (existing != null &&
        existing.name.isNotEmpty &&
        !_queueTypeNameOptions.contains(existing.name)) {
      _queueTypeNameOptions.insert(0, existing.name);
    }

    _selectedName = existing?.name;
    _maxPartyController =
        TextEditingController(text: existing?.maxPartySize?.toString() ?? '');
    _durationController = TextEditingController(
      text: existing?.standardServiceDuration?.toString() ?? '45',
    );
    _isActive = existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _maxPartyController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _selectedName!;
    final maxParty = int.parse(_maxPartyController.text.trim());
    final duration = int.parse(_durationController.text.trim());

    Navigator.pop(
      context,
      _QueueTypeFormResult(
        name: name,
        maxPartySize: maxParty,
        durationMinutes: duration,
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.mode == _FormMode.edit;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5D9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFC928),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEdit ? 'Edit Queue Type' : 'Add Queue Type',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔽 DROPDOWN chọn tên queue type
                DropdownButtonFormField<String>(
                  value: _selectedName != null &&
                      _queueTypeNameOptions.contains(_selectedName)
                      ? _selectedName
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Tên loại bàn / queue type',
                    border: OutlineInputBorder(),
                  ),
                  items: _queueTypeNameOptions
                      .map(
                        (name) => DropdownMenuItem<String>(
                      value: name,
                      child: Text(name),
                    ),
                  )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedName = val;
                    });
                  },
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng chọn loại bàn';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _maxPartyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Số khách tối đa',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Nhập số khách';
                          }
                          final n = int.tryParse(v);
                          if (n == null || n <= 0) {
                            return 'Số không hợp lệ';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Thời lượng (phút/bàn)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Nhập thời lượng';
                          }
                          final n = int.tryParse(v);
                          if (n == null || n <= 0) {
                            return 'Số không hợp lệ';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Đang hoạt động',
                      style: TextStyle(fontSize: 14),
                    ),
                    const Spacer(),
                    Switch(
                      value: _isActive,
                      activeColor: Colors.green,
                      onChanged: (val) {
                        setState(() => _isActive = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC928),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(isEdit ? 'Save changes' : 'Create'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
