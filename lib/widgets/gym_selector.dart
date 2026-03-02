import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/climbing_gym.dart';
import '../providers/gym_provider.dart';

class GymSelector extends ConsumerStatefulWidget {
  final ClimbingGym? selectedGym;
  final String? manualGymName;
  final ValueChanged<ClimbingGym?> onGymSelected;
  final ValueChanged<String> onManualInput;

  const GymSelector({
    super.key,
    this.selectedGym,
    this.manualGymName,
    required this.onGymSelected,
    required this.onManualInput,
  });

  @override
  ConsumerState<GymSelector> createState() => _GymSelectorState();
}

class _GymSelectorState extends ConsumerState<GymSelector> {
  bool _isManualMode = false;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.manualGymName != null) {
      _isManualMode = true;
      _controller.text = widget.manualGymName!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nearbyGyms = ref.watch(nearbyGymsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('클라이밍장',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton(
              onPressed: () => setState(() => _isManualMode = !_isManualMode),
              child: Text(_isManualMode ? '목록에서 선택' : '직접 입력'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isManualMode)
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: '클라이밍장 이름 입력',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            textInputAction: TextInputAction.done,
            onChanged: widget.onManualInput,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
          )
        else
          nearbyGyms.when(
            data: (gyms) => gyms.isEmpty
                ? const Text('등록된 클라이밍장이 없습니다. 직접 입력해주세요.',
                    style: TextStyle(color: Colors.grey))
                : SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: gyms.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final gym = gyms[i];
                        final isSelected = gym.name == widget.selectedGym?.name;
                        return ChoiceChip(
                          label: Text(gym.name),
                          selected: isSelected,
                          onSelected: (_) => widget.onGymSelected(gym),
                        );
                      },
                    ),
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) =>
                Text('위치 정보를 가져올 수 없습니다', style: TextStyle(color: Colors.red.shade700)),
          ),
      ],
    );
  }
}
