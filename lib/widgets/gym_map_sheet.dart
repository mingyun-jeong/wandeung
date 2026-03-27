import 'package:flutter/material.dart';
import 'instagram_icon.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/climbing_gym.dart';
import '../providers/gym_instagram_provider.dart';
import '../providers/gym_provider.dart';

final _mapPickerQueryProvider = StateProvider<String>((ref) => '');

class GymMapSheet extends ConsumerStatefulWidget {
  final ClimbingGym? selectedGym;
  final ValueChanged<ClimbingGym>? onGymSelected;

  const GymMapSheet({
    super.key,
    this.selectedGym,
    this.onGymSelected,
  });

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
  GoogleMapController? _controller;
  ClimbingGym? _tappedGym;
  List<ClimbingGym> _gyms = [];
  final _searchController = TextEditingController();
  bool _showSearchResults = false;

  bool get _isPickMode => widget.onGymSelected != null;

  @override
  void initState() {
    super.initState();
    _tappedGym = widget.selectedGym;
    // 지도에서 찾기 모드: 열릴 때 기본으로 근처 클라이밍장 조회 후 목록 표시
    if (_isPickMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(searchQueryProvider.notifier).state = '';
        setState(() => _showSearchResults = true);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;

    if (_isPickMode) {
      ref.read(userPositionProvider.future).then((pos) {
        if (pos != null && mounted) {
          controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(pos.latitude, pos.longitude),
                zoom: 14,
              ),
            ),
          );
        }
      });
    }
  }

  bool _isSameGym(ClimbingGym? a, ClimbingGym? b) {
    if (a == null || b == null) return false;
    if (a.googlePlaceId != null && b.googlePlaceId != null) {
      return a.googlePlaceId == b.googlePlaceId;
    }
    return a.name == b.name;
  }

  Set<Marker> _buildMarkers() {
    return _gyms
        .where((gym) => gym.latitude != null && gym.longitude != null)
        .map((gym) {
          final isTapped = _isSameGym(_tappedGym, gym);
          final isPreSelected = _isSameGym(widget.selectedGym, gym);
          final isHighlighted = isTapped || isPreSelected;

          return Marker(
            markerId: MarkerId(gym.googlePlaceId ?? gym.name),
            position: LatLng(gym.latitude!, gym.longitude!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isHighlighted
                  ? BitmapDescriptor.hueAzure
                  : BitmapDescriptor.hueRed,
            ),
            onTap: () {
              setState(() => _tappedGym = gym);
              _controller?.animateCamera(
                CameraUpdate.newLatLng(
                  LatLng(gym.latitude!, gym.longitude!),
                ),
              );
            },
          );
        })
        .toSet();
  }

  void _onSearch(String query) {
    if (_isPickMode) {
      ref.read(_mapPickerQueryProvider.notifier).state = query.trim();
      ref.read(searchQueryProvider.notifier).state = query.trim();
      setState(() => _showSearchResults = true);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    if (_isPickMode) {
      ref.read(_mapPickerQueryProvider.notifier).state = '';
      ref.read(searchQueryProvider.notifier).state = '';
      setState(() => _showSearchResults = true);
    }
  }

  void _selectFromList(ClimbingGym gym) {
    setState(() {
      _tappedGym = gym;
      _showSearchResults = false;
    });
    if (gym.latitude != null && gym.longitude != null) {
      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(gym.latitude!, gym.longitude!), 15,
        ),
      );
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

    final gymsAsync = _isPickMode
        ? ref.watch(gymsProvider)
        : ref.watch(nearbyGymsProvider);

    ref.listen(
      _isPickMode ? gymsProvider : nearbyGymsProvider,
      (_, next) {
        next.whenData((gyms) {
          setState(() {
            _gyms = gyms;
            if (_isPickMode && _tappedGym == null && gyms.isNotEmpty) {
              _tappedGym = gyms.first;
              _showSearchResults = false;
              if (_tappedGym!.latitude != null && _tappedGym!.longitude != null) {
                _controller?.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(_tappedGym!.latitude!, _tappedGym!.longitude!), 15,
                  ),
                );
              }
            }
          });
        });
      },
    );

    gymsAsync.whenData((gyms) {
      if (_gyms.isEmpty) {
        _gyms = gyms;
        if (_isPickMode && _tappedGym == null && gyms.isNotEmpty) {
          _tappedGym = gyms.first;
          _showSearchResults = false;
        }
      }
    });

    final initialTarget = widget.selectedGym != null &&
            widget.selectedGym!.latitude != null &&
            widget.selectedGym!.longitude != null
        ? LatLng(widget.selectedGym!.latitude!, widget.selectedGym!.longitude!)
        : const LatLng(37.5665, 126.9780);

    return Column(
      children: [
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

        if (_isPickMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearch,
              decoration: InputDecoration(
                hintText: '근처 클라이밍장',
                prefixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded, size: 20),
                  onPressed: () => _onSearch(_searchController.text),
                  style: IconButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                suffixIcon: pickerQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: _clearSearch,
                      )
                    : TextButton(
                        onPressed: () => _onSearch(
                            _searchController.text.trim().isEmpty
                                ? ''
                                : _searchController.text.trim()),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          foregroundColor: colorScheme.primary,
                        ),
                        child: const Text('찾기',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
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

        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: initialTarget,
                  zoom: _isPickMode ? 14 : 15,
                ),
                markers: _buildMarkers(),
                myLocationEnabled: _isPickMode,
                myLocationButtonEnabled: _isPickMode,
                onMapCreated: _onMapCreated,
                onTap: (_) {
                  if (_isPickMode) {
                    setState(() {
                      _tappedGym = null;
                    });
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
              if (_isPickMode && _showSearchResults)
                Positioned.fill(
                  child: Container(
                    color: colorScheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              Text(
                                pickerQuery.isEmpty
                                    ? '근처 클라이밍장'
                                    : '검색 결과',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () =>
                                    setState(() => _showSearchResults = false),
                                tooltip: '목록 닫기',
                                style: IconButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.all(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: gymsAsync.when(
                            data: (gyms) {
                              if (gyms.isEmpty) {
                                return Center(
                                  child: Text(
                                    pickerQuery.isEmpty
                                        ? '주변 클라이밍장을 찾을 수 없습니다'
                                        : '검색 결과가 없습니다',
                                    style: TextStyle(
                                      color: colorScheme.onSurface
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                );
                              }
                              return ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                itemCount: gyms.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final gym = gyms[index];
                                  final dist = _formatDistance(gym);
                                  return Material(
                                    color: colorScheme.surfaceContainerHighest
                                        .withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      onTap: () => _selectFromList(gym),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor:
                                                  colorScheme.primaryContainer,
                                              child: Icon(
                                                Icons.terrain_rounded,
                                                size: 20,
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    gym.name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                  if (gym.address != null)
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .only(top: 4),
                                                      child: Text(
                                                        gym.address!,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: colorScheme
                                                              .onSurface
                                                              .withOpacity(0.6),
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (dist.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 8),
                                                child: Text(
                                                  dist,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: colorScheme.primary,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              color: colorScheme.onSurface
                                                  .withOpacity(0.4),
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            loading: () => const Center(
                                child: CircularProgressIndicator()),
                            error: (_, __) => Center(
                              child: Text(
                                '오류가 발생했습니다',
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        _buildBottomCard(colorScheme, ref),
      ],
    );
  }

  Widget _buildBottomCard(ColorScheme colorScheme, WidgetRef ref) {
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
            _InstagramIconButton(
              gymName: gym.name,
              directUrl: gym.instagramUrl,
              colorScheme: colorScheme,
            ),
            if (_isPickMode) ...[
              const SizedBox(width: 8),
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

/// 인스타그램 아이콘 버튼 (directUrl이 없으면 DB에서 조회)
class _InstagramIconButton extends ConsumerWidget {
  final String gymName;
  final String? directUrl;
  final ColorScheme colorScheme;

  const _InstagramIconButton({
    required this.gymName,
    required this.directUrl,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instagramUrl = directUrl ??
        ref.watch(gymInstagramProvider(gymName)).valueOrNull;

    if (instagramUrl == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IconButton(
        onPressed: () async {
          final uri = Uri.parse(instagramUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        icon: const InstagramIcon(size: 20),
        tooltip: 'Instagram',
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.primary,
          backgroundColor: colorScheme.primaryContainer.withOpacity(0.5),
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(36, 36),
        ),
      ),
    );
  }
}
