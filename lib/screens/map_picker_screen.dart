import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, this.initialPosition});

  final LatLng? initialPosition;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const LatLng _defaultCenter = LatLng(20.5937, 78.9629);

  GoogleMapController? _controller;
  late LatLng _selectedPosition = widget.initialPosition ?? _defaultCenter;

  Future<void> _animateTo(LatLng position) async {
    setState(() {
      _selectedPosition = position;
    });
    await _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedPosition,
              zoom: widget.initialPosition == null ? 4.8 : 15,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('selected-location'),
                position: _selectedPosition,
              ),
            },
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) {
              _controller = controller;
              _animateTo(_selectedPosition);
            },
            onTap: _animateTo,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_selectedPosition.latitude.toStringAsFixed(5)}, '
                        '${_selectedPosition.longitude.toStringAsFixed(5)}',
                      ),
                    ),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(_selectedPosition),
                      child: const Text('Confirm'),
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
    _controller?.dispose();
    super.dispose();
  }
}
