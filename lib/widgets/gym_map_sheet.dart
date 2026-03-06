import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/climbing_gym.dart';
import '../providers/gym_provider.dart';

/// Local search query for the map picker, separate from MapTabScreen's searchQueryProvider.
final _mapPickerQueryProvider = StateProvider<String>((ref) => '');

class GymMapSheet extends ConsumerStatefulWidget {
  final ClimbingGym? selectedGym;
  final ValueChanged<ClimbingGym>? onGymSelected;

  const GymMapSheet({
    super.key,
    this.selectedGym,
    this.onGymSelected,
  });

  /// Read-only mode: show a selected gym on the map
  static Future<void> show(BuildContext context,
      {required ClimbingGym selectedGym}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      enableDrag: false,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.7,
        child: GymMapSheet(selectedGym: selectedGym),
      ),
    );
  }

  /// Selection mode: pick a gym from the map, returns the chosen gym
  static Future<ClimbingGym?> pick(BuildContext context) {
    return showModalBottomSheet<ClimbingGym>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      enableDrag: false,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.8,
        child: GymMapSheet(
          onGymSelected: (gym) => Navigator.pop(ctx, gym),
        ),
      ),
    );
  }

  @override
  ConsumerState<GymMapSheet> createState() => _GymMapSheetState();
}

class _GymMapSheetState extends ConsumerState<GymMapSheet> {
  NaverMapController? _controller;
  bool _disposed = false;
  ClimbingGym? _tappedGym;
  List<ClimbingGym> _gyms = [];
  final _searchController = TextEditingController();

  bool get _isPickMode => widget.onGymSelected != null;

  @override
  void initState() {
    super.initState();
    _tappedGym = widget.selectedGym;
  }

  @override
  void dispose() {
    _disposed = true;
    _searchController.dispose();
    // Reset picker search query on close
    if (_isPickMode) {
      ref.read(_mapPickerQueryProvider.notifier).state = '';
    }
    super.dispose();
  }

  void _onMapReady(NaverMapController controller) {
    if (_disposed) return;
    _controller = controller;

    if (_isPickMode) {
      ref.read(userPositionProvider.future).then((pos) {
        if (pos != null && !_disposed) {
          controller.updateCamera(
            NCameraUpdate.scrollAndZoomTo(
              target: NLatLng(pos.latitude, pos.longitude),
              zoom: 14,
            ),
          );
        }
      });
    }

    _refreshMarkers();
  }

  Future<void> _refreshMarkers() async {
    final controller = _controller;
    if (controller == null || _disposed || !mounted) return;

    final colorScheme = Theme.of(context).colorScheme;

    await controller.clearOverlays();
    if (_disposed || !mounted) return;

    for (final gym in _gyms) {
      if (gym.latitude == null || gym.longitude == null) continue;

      final isTapped = _tappedGym?.name == gym.name;
      final isPreSelected = widget.selectedGym?.name == gym.name;
      final isHighlighted = isTapped || isPreSelected;

      final marker = NMarker(
        id: gym.name,
        position: NLatLng(gym.latitude!, gym.longitude!),
      );
      marker.setIconTintColor(
          isHighlighted ? colorScheme.primary : Colors.grey);
      marker.setSize(isHighlighted ? const Size(28, 36) : const Size(20, 26));

      marker.setOnTapListener((_) {
        setState(() => _tappedGym = gym);
        _refreshMarkers();
        controller.updateCamera(
          NCameraUpdate.scrollAndZoomTo(
            target: NLatLng(gym.latitude!, gym.longitude!),
          ),
        );
      });

      await controller.addOverlay(marker);
    }
  }

  void _onSearch(String query) {
    if (_isPickMode) {
      ref.read(_mapPickerQueryProvider.notifier).state = query.trim();
      // Also update global search so gymsProvider picks it up
      ref.read(searchQueryProvider.notifier).state = query.trim();
    }
  }

  void _clearSearch() {
    _searchController.clear();
    if (_isPickMode) {
      ref.read(_mapPickerQueryProvider.notifier).state = '';
      ref.read(searchQueryProvider.notifier).state = '';
    }
  }

  String _formatDistance(ClimbingGym gym) {
    final pos = ref.read(userPositionProvider).valueOrNull;
    if (pos == null || gym.latitude == null || gym.longitude == null) return '';
    final dist = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, gym.latitude!, gym.longitude!);
    if (dist < 1000) return '${dist.round()}m';
    return '${(dist / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pickerQuery = ref.watch(_mapPickerQueryProvider);

    // Watch the appropriate provider
    final gymsAsync = _isPickMode
        ? ref.watch(gymsProvider)
        : ref.watch(nearbyGymsProvider);

    // Sync local gym list
    ref.listen(
      _isPickMode ? gymsProvider : nearbyGymsProvider,
      (_, next) {
        next.whenData((gyms) {
          _gyms = gyms;
          _refreshMarkers();
        });
      },
    );

    // Initialize gyms on first data
    gymsAsync.whenData((gyms) {
      if (_gyms.isEmpty) {
        _gyms = gyms;
      }
    });

    final initialTarget = widget.selectedGym != null &&
            widget.selectedGym!.latitude != null &&
            widget.selectedGym!.longitude != null
        ? NLatLng(widget.selectedGym!.latitude!, widget.selectedGym!.longitude!)
        : const NLatLng(37.5665, 126.9780);

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(_isPickMode ? '지도에서 찾기' : '위치 확인',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        // Search bar (pick mode only)
        if (_isPickMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearch,
              decoration: InputDecoration(
                hintText: '클라이밍장 검색...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: pickerQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),

        // Map
        Expanded(
          child: Stack(
            children: [
              NaverMap(
                options: NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: initialTarget,
                    zoom: _isPickMode ? 14 : 15,
                  ),
                  locationButtonEnable: _isPickMode,
                ),
                onMapReady: _onMapReady,
                onMapTapped: (_, __) {
                  if (_isPickMode) {
                    setState(() => _tappedGym = null);
                    _refreshMarkers();
                  }
                },
              ),
              if (gymsAsync.isLoading)
                const Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('검색 중…',
                                style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Bottom info card
        _buildBottomCard(colorScheme),
      ],
    );
  }

  Widget _buildBottomCard(ColorScheme colorScheme) {
    final gym = _tappedGym ?? widget.selectedGym;

    if (gym == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          top: false,
          child: Text(
            '마커를 탭하여 암장을 선택하세요',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final dist = _formatDistance(gym);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(Icons.location_on, color: colorScheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gym.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (gym.address != null || dist.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        [
                          if (gym.address != null) gym.address!,
                          if (dist.isNotEmpty) dist,
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            if (_isPickMode) ...[
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => widget.onGymSelected!(gym),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text('선택'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
