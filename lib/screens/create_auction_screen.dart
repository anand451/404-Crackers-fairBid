import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/auction_service.dart';
import 'map_picker_screen.dart';

class CreateAuctionScreen extends StatefulWidget {
  const CreateAuctionScreen({
    super.key,
    this.embedded = false,
    this.onCreated,
  });

  final bool embedded;
  final VoidCallback? onCreated;

  @override
  State<CreateAuctionScreen> createState() => _CreateAuctionScreenState();
}

class _CreateAuctionScreenState extends State<CreateAuctionScreen> {
  static const List<String> _categories = [
    'Vehicle',
    'Electronics',
    'Jewellery',
    'Land',
    'Furniture',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _reserveController = TextEditingController();
  final _durationController = TextEditingController();

  String _selectedCategory = _categories.first;
  DateTime? _selectedStartTime;
  LatLng? _selectedLocation;
  bool _isSubmitting = false;
  double _buttonScale = 1;

  bool get _requiresLocation => _selectedCategory == 'Land';

  Future<void> _pickStartTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedStartTime ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF0F766E),
                  secondary: const Color(0xFFFFC107),
                ),
          ),
          child: child!,
        );
      },
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _selectedStartTime ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null) {
      return;
    }

    setState(() {
      _selectedStartTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickLocation() async {
    final location = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initialPosition: _selectedLocation),
      ),
    );
    if (location == null) {
      return;
    }
    setState(() {
      _selectedLocation = location;
    });
  }

  Future<void> _createAuction() async {
    final startTime = _selectedStartTime;
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (startTime == null) {
      _showSnackBar('Please choose auction date and time.', isError: true);
      return;
    }
    if (!startTime.isAfter(DateTime.now())) {
      _showSnackBar('Auction start time must be in the future.', isError: true);
      return;
    }
    if (_requiresLocation && _selectedLocation == null) {
      _showSnackBar('Please select land location on the map.', isError: true);
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final userProfile = authProvider.userProfile;
    if (!authProvider.canInteract || userProfile == null) {
      _showSnackBar('Please sign in again and try once more.', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AuctionService().submitAuctionRequest(
        title: _titleController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
        reservePrice: double.parse(_reserveController.text),
        startTime: startTime,
        durationHours: int.parse(_durationController.text),
        latitude: _selectedLocation?.latitude,
        longitude: _selectedLocation?.longitude,
        seller: userProfile,
      );

      if (!mounted) {
        return;
      }

      _resetForm();
      widget.onCreated?.call();
      _showSnackBar('Auction request submitted for admin approval.');
      if (!widget.embedded && mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Auction request failed: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    _reserveController.clear();
    _durationController.clear();
    setState(() {
      _selectedCategory = _categories.first;
      _selectedStartTime = null;
      _selectedLocation = null;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? const Color(0xFFEF4444) : null,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Form(
      key: _formKey,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(0, widget.embedded ? 0 : 24, 0, 120),
        children: [
          _AnimatedFormSection(
            index: 0,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedCategory = value;
                  if (!_requiresLocation) {
                    _selectedLocation = null;
                  }
                });
              },
            ),
          ),
          _AnimatedFormSection(
            index: 1,
            child: TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Auction Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) =>
                  value?.trim().isEmpty == true ? 'Title required' : null,
            ),
          ),
          _AnimatedFormSection(
            index: 2,
            child: TextFormField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description_outlined),
                alignLabelWithHint: true,
              ),
              validator: (value) =>
                  value?.trim().isEmpty == true ? 'Description required' : null,
            ),
          ),
          _AnimatedFormSection(
            index: 3,
            child: OutlinedButton.icon(
              onPressed: _pickStartTime,
              icon: const Icon(Icons.calendar_month_rounded),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _selectedStartTime == null
                      ? 'Choose Date & Time'
                      : DateFormat('dd MMM yyyy, hh:mm a')
                          .format(_selectedStartTime!),
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          _AnimatedFormSection(
            index: 4,
            child: TextFormField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Auction Duration (hours)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer_outlined),
              ),
              validator: (value) {
                final hours = int.tryParse(value ?? '');
                if (hours == null || hours <= 0) {
                  return 'Valid duration required';
                }
                return null;
              },
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0, -0.08),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: _requiresLocation
                ? _AnimatedFormSection(
                    key: const ValueKey('land-location'),
                    index: 5,
                    child: _LocationSelector(
                      location: _selectedLocation,
                      onSelect: _pickLocation,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no-location')),
          ),
          _AnimatedFormSection(
            index: 6,
            child: TextFormField(
              controller: _reserveController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Starting Price',
                prefixText: 'Rs ',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
              validator: (value) {
                final price = double.tryParse(value ?? '');
                if (price == null || price <= 0) {
                  return 'Starting price must be greater than 0';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 10),
          AnimatedScale(
            scale: _buttonScale,
            duration: const Duration(milliseconds: 140),
            child: GestureDetector(
              onTapDown: _isSubmitting
                  ? null
                  : (_) => setState(() {
                        _buttonScale = 0.98;
                      }),
              onTapUp: _isSubmitting
                  ? null
                  : (_) => setState(() {
                        _buttonScale = 1;
                      }),
              onTapCancel: _isSubmitting
                  ? null
                  : () => setState(() {
                        _buttonScale = 1;
                      }),
              child: SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _createAuction,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting ? 'Submitting...' : 'Submit Auction',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Create Auction')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: content,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _reserveController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}

class _AnimatedFormSection extends StatelessWidget {
  const _AnimatedFormSection({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + index * 45),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: child,
      ),
    );
  }
}

class _LocationSelector extends StatelessWidget {
  const _LocationSelector({
    required this.location,
    required this.onSelect,
  });

  final LatLng? location;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.map_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  location == null
                      ? 'Select land location on map'
                      : '${location!.latitude.toStringAsFixed(5)}, '
                          '${location!.longitude.toStringAsFixed(5)}',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
