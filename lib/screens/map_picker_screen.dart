import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/widgets/app_state_widgets.dart';
import '../services/place_search_service.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, this.initialPosition});

  final LatLng? initialPosition;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const LatLng _defaultCenter = LatLng(20.5937, 78.9629);

  final PlaceSearchService _placeSearchService = PlaceSearchService();
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _controller;
  Timer? _searchDebounce;

  late LatLng _selectedPosition = widget.initialPosition ?? _defaultCenter;
  MapType _mapType = MapType.normal;
  bool _fullScreenMap = false;
  bool _isSearching = false;
  List<PlaceSuggestion> _suggestions = const <PlaceSuggestion>[];

  Future<void> _animateTo(LatLng position) async {
    setState(() {
      _selectedPosition = position;
    });
    await _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 16),
      ),
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final query = value.trim();
      if (query.length < 3) {
        if (mounted) {
          setState(() {
            _isSearching = false;
            _suggestions = const <PlaceSuggestion>[];
          });
        }
        return;
      }

      setState(() {
        _isSearching = true;
      });
      final results = await _placeSearchService.autocomplete(query);
      if (!mounted || _searchController.text.trim() != query) {
        return;
      }
      setState(() {
        _isSearching = false;
        _suggestions = results;
      });
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    _searchController.text = suggestion.title;
    setState(() {
      _suggestions = const <PlaceSuggestion>[];
    });
    await _animateTo(suggestion.position);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showSearchResults = _suggestions.isNotEmpty || _isSearching;

    return Scaffold(
      extendBodyBehindAppBar: _fullScreenMap,
      appBar: _fullScreenMap
          ? null
          : AppBar(
              title: const Text('Select Location'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_selectedPosition),
                  child: const Text('Use'),
                ),
              ],
            ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedPosition,
                zoom: widget.initialPosition == null ? 4.8 : 15,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('selected-location'),
                  position: _selectedPosition,
                  draggable: true,
                  onDragEnd: _animateTo,
                ),
              },
              mapType: _mapType,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              onMapCreated: (controller) {
                _controller = controller;
                _animateTo(_selectedPosition);
              },
              onTap: _animateTo,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (_fullScreenMap)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(
                              alpha: 0.96,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                _fullScreenMap = false;
                              });
                            },
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                      if (_fullScreenMap) const SizedBox(width: 12),
                      Expanded(
                        child: Material(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.96,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'Search for a place or area',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : (_searchController.text.trim().isEmpty
                                      ? null
                                      : IconButton(
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _suggestions =
                                                  const <PlaceSuggestion>[];
                                            });
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                        )),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (showSearchResults) ...[
                    const SizedBox(height: 12),
                    Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 260),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: _isSearching
                            ? const AppLoadingIndicator(
                                label: 'Searching places...',
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: _suggestions.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final suggestion = _suggestions[index];
                                  return ListTile(
                                    leading: const Icon(Icons.place_outlined),
                                    title: Text(suggestion.title),
                                    subtitle: suggestion.subtitle.isEmpty
                                        ? null
                                        : Text(
                                            suggestion.subtitle,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                    onTap: () => _selectSuggestion(suggestion),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: _fullScreenMap ? 140 : 160,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'map_type',
                  onPressed: () {
                    setState(() {
                      _mapType = _mapType == MapType.normal
                          ? MapType.satellite
                          : MapType.normal;
                    });
                  },
                  child: Icon(
                    _mapType == MapType.normal
                        ? Icons.satellite_alt_outlined
                        : Icons.map_outlined,
                  ),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'fullscreen',
                  onPressed: () {
                    setState(() {
                      _fullScreenMap = !_fullScreenMap;
                    });
                  },
                  child: Icon(
                    _fullScreenMap
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_selectedPosition.latitude.toStringAsFixed(5)}, '
                            '${_selectedPosition.longitude.toStringAsFixed(5)}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pop(_selectedPosition),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Confirm Location'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _placeSearchService.dispose();
    _controller?.dispose();
    super.dispose();
  }
}
