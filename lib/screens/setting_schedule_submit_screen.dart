import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../app.dart';
import '../models/climbing_gym.dart';
import '../models/gym_setting_schedule.dart';
import '../providers/gym_provider.dart';
import '../providers/setting_schedule_provider.dart';

class SettingScheduleSubmitScreen extends ConsumerStatefulWidget {
  final String? prefilledGymName;

  const SettingScheduleSubmitScreen({super.key, this.prefilledGymName});

  @override
  ConsumerState<SettingScheduleSubmitScreen> createState() =>
      _SettingScheduleSubmitScreenState();
}

class _SettingScheduleSubmitScreenState
    extends ConsumerState<SettingScheduleSubmitScreen> {
  File? _imageFile;
  GymSettingSchedule? _parsedSchedule;
  bool _isParsing = false;
  bool _isSubmitting = false;
  String? _error;
  bool _showGymSearchResults = false;
  ClimbingGym? _selectedGym;

  late TextEditingController _gymNameController;
  late TextEditingController _yearMonthController;

  @override
  void initState() {
    super.initState();
    _gymNameController =
        TextEditingController(text: widget.prefilledGymName ?? '');
    final now = DateTime.now();
    _yearMonthController = TextEditingController(
      text: '${now.year}-${now.month.toString().padLeft(2, '0')}',
    );
  }

  @override
  void dispose() {
    _gymNameController.dispose();
    _yearMonthController.dispose();
    super.dispose();
  }

  void _showMonthPicker() {
    // _yearMonthController에서 현재 선택 값 파싱
    final parts = _yearMonthController.text.split('-');
    int selectedYear =
        parts.isNotEmpty ? int.tryParse(parts[0]) ?? DateTime.now().year : DateTime.now().year;
    int selectedMonth =
        parts.length >= 2 ? int.tryParse(parts[1]) ?? DateTime.now().month : DateTime.now().month;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 년도 선택
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () =>
                            setModalState(() => selectedYear--),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Text(
                        '$selectedYear년',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            setModalState(() => selectedYear++),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 월 그리드
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 12,
                    itemBuilder: (_, i) {
                      final month = i + 1;
                      final isSelected = month == selectedMonth;
                      return GestureDetector(
                        onTap: () {
                          final ym =
                              '$selectedYear-${month.toString().padLeft(2, '0')}';
                          _yearMonthController.text = ym;
                          setState(() {});
                          Navigator.pop(context);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ClimpickColors.accent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? null
                                : Border.all(
                                    color: ClimpickColors.border),
                          ),
                          child: Text(
                            '$month월',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? Colors.white
                                  : ClimpickColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _selectGym(ClimbingGym gym) {
    _selectedGym = gym;
    _gymNameController.text = gym.name;
    setState(() => _showGymSearchResults = false);
    FocusScope.of(context).unfocus();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _imageFile = File(picked.path);
      _error = null;
    });

    await _parseImage();
  }

  Future<void> _parseImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isParsing = true;
      _error = null;
    });

    try {
      final result =
          await SettingScheduleService.parseScheduleImage(_imageFile!);
      if (result != null) {
        setState(() {
          _parsedSchedule = result;
          if (result.gymName != null &&
              result.gymName!.isNotEmpty &&
              _gymNameController.text.isEmpty) {
            _gymNameController.text = result.gymName!;
          }
          if (result.yearMonth.isNotEmpty) {
            _yearMonthController.text = result.yearMonth;
          }
        });
      }
    } catch (e) {
      setState(() => _error = '이미지 분석에 실패했습니다: $e');
    } finally {
      setState(() => _isParsing = false);
    }
  }

  Future<void> _submit() async {
    final yearMonth = _yearMonthController.text.trim();

    if (_selectedGym == null) {
      setState(() => _error = '암장을 검색하여 선택해주세요');
      return;
    }
    if (yearMonth.isEmpty ||
        !RegExp(r'^\d{4}-\d{2}$').hasMatch(yearMonth)) {
      setState(() => _error = '년월을 YYYY-MM 형식으로 입력해주세요');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await SettingScheduleService.submitSchedule(
        gym: _selectedGym!,
        yearMonth: yearMonth,
        sectors: _parsedSchedule?.sectors ?? [],
        sourceImage: _imageFile,
      );

      // 캐시 무효화
      ref.invalidate(settingSchedulesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('세팅일정이 등록되었습니다!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = '등록 실패: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '세팅일정 등록',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: _isParsing ? _buildParsingView() : _buildFormView(),
    );
  }

  Widget _buildParsingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: ClimpickColors.accent),
          SizedBox(height: 20),
          Text(
            'AI가 일정을 분석중...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ClimpickColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '잠시만 기다려주세요',
            style: TextStyle(
              fontSize: 13,
              color: ClimpickColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── 암장명 (Google Places 검색) ───
          const Text('암장명',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ClimpickColors.textPrimary)),
          const SizedBox(height: 6),
          TextField(
            controller: _gymNameController,
            decoration: InputDecoration(
              hintText: '암장 검색...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _gymNameController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _gymNameController.clear();
                        _selectedGym = null;
                        ref.read(searchQueryProvider.notifier).state = '';
                        setState(() => _showGymSearchResults = false);
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (query) {
              if (query.isNotEmpty) {
                ref.read(searchQueryProvider.notifier).state = query;
                setState(() => _showGymSearchResults = true);
              } else {
                setState(() => _showGymSearchResults = false);
              }
            },
            onTap: () {
              if (_gymNameController.text.isNotEmpty) {
                ref.read(searchQueryProvider.notifier).state =
                    _gymNameController.text;
                setState(() => _showGymSearchResults = true);
              }
            },
          ),
          if (_showGymSearchResults) _buildGymSearchResults(),
          const SizedBox(height: 16),

          // ─── 년월 ───
          const Text('년월',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ClimpickColors.textPrimary)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _showMonthPicker(),
            child: AbsorbPointer(
              child: TextField(
                controller: _yearMonthController,
                decoration: InputDecoration(
                  prefixIcon:
                      const Icon(Icons.calendar_month_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── 스크린샷 등록 ───
          const Text('세팅일정 스크린샷',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ClimpickColors.textPrimary)),
          const SizedBox(height: 6),
          _buildImageSection(),

          const SizedBox(height: 24),

          // ─── 에러 메시지 ───
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),

          // ─── 등록 버튼 ───
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '등록하기',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGymSearchResults() {
    final gymsAsync = ref.watch(gymsProvider);
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ClimpickColors.border),
      ),
      child: gymsAsync.when(
        data: (gyms) {
          if (gyms.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Text('검색 결과가 없습니다',
                  style: TextStyle(
                      fontSize: 13, color: ClimpickColors.textSecondary)),
            );
          }
          return ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: gyms.length,
            itemBuilder: (_, i) {
              final gym = gyms[i];
              return ListTile(
                leading: const Icon(Icons.location_on_outlined,
                    size: 18, color: ClimpickColors.accent),
                title: Text(gym.name,
                    style: const TextStyle(fontSize: 14)),
                subtitle: gym.address != null
                    ? Text(gym.address!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: ClimpickColors.textTertiary),
                        overflow: TextOverflow.ellipsis)
                    : null,
                onTap: () => _selectGym(gym),
                dense: true,
                visualDensity: VisualDensity.compact,
              );
            },
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(12),
          child: Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(12),
          child: Text('오류: $e',
              style: const TextStyle(
                  fontSize: 13, color: ClimpickColors.textSecondary)),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    if (_imageFile != null) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _imageFile!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('다른 이미지 선택'),
          ),
        ],
      );
    }

    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: ClimpickColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ClimpickColors.border,
            width: 1.5,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined,
                size: 40, color: ClimpickColors.textTertiary),
            SizedBox(height: 8),
            Text(
              '세팅일정 스크린샷 선택',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: ClimpickColors.textSecondary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'AI가 자동으로 분석합니다',
              style: TextStyle(
                fontSize: 12,
                color: ClimpickColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
