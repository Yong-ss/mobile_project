import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/shimmer_skeletons.dart';

// Member 2: Location Screen — shows pickup location on map
// Integrated Google Maps and Geolocator to pick and save Location.
class LocationScreen extends StatefulWidget {
  final bool isReadOnly;
  final double? initialLat;
  final double? initialLng;
  final List<Map<String, dynamic>>? stores;

  const LocationScreen({
    super.key,
    this.isReadOnly = false,
    this.initialLat,
    this.initialLng,
    this.stores,
  });

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  LatLng? _selectedLocation;

  String _storeName = 'Select a location';
  String _storeAddress = 'Tap a red marker on the map';
  String _storeHours = '-';
  bool _isInitialLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  late List<Map<String, dynamic>> _stores;

  // Premium Nocturnal Map Style (Updated for better compatibility)
  static const String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [ { "color": "#242f3e" } ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [ { "color": "#242f3e" } ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [ { "color": "#746855" } ]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels.text.fill",
    "stylers": [ { "color": "#d59563" } ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [ { "color": "#d59563" } ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [ { "color": "#263c3f" } ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [ { "color": "#6b9a76" } ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [ { "color": "#38414e" } ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [ { "color": "#212a37" } ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [ { "color": "#9ca5b3" } ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [ { "color": "#746855" } ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [ { "color": "#1f2835" } ]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [ { "color": "#f3d19c" } ]
  },
  {
    "featureType": "transit",
    "elementType": "geometry",
    "stylers": [ { "color": "#2f3948" } ]
  },
  {
    "featureType": "transit.station",
    "elementType": "labels.text.fill",
    "stylers": [ { "color": "#d59563" } ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [ { "color": "#17263c" } ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [ { "color": "#515c6d" } ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.stroke",
    "stylers": [ { "color": "#17263c" } ]
  }
]
''';

  void _setupMarkers() {
    _markers.clear();
    if (_stores.isNotEmpty) {
      for (var store in _stores) {
        _markers.add(
          Marker(
            markerId: MarkerId(store['id']),
            position: store['latLng'],
            infoWindow: InfoWindow(title: store['name']),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            onTap: () {
              setState(() {
                _selectedLocation = store['latLng'];
                _storeName = store['name'];
                _storeAddress = store['street'];
                _storeHours = store['hours'];
              });
            },
          ),
        );
      }
    } else if (_selectedLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('custom_pin'),
          position: _selectedLocation!,
          infoWindow: InfoWindow(title: _storeName),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Premium reveal: show shimmer for at least 800ms
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isInitialLoading = false);
    });

    // If stores is null, we are in "Delivery" mode. Don't show the hardcoded stores.
    _stores = widget.stores ?? [];

    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedLocation = LatLng(widget.initialLat!, widget.initialLng!);

      // Attempt to find the store details from the list for initial display
      for (var store in _stores) {
        if (store['latLng'].latitude == widget.initialLat && store['latLng'].longitude == widget.initialLng) {
          _storeName = store['name'];
          _storeAddress = store['street'];
          _storeHours = store['hours'];
          break;
        }
      }

      _markers.add(
        Marker(
          markerId: const MarkerId('initial_location'),
          position: _selectedLocation!,
          infoWindow: InfoWindow(title: _storeName),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
      _setupMarkers();
      _isLoading = false;
    } else {
      _setupMarkers();
      _checkPermissionsAndGetLocation();
    }
  }

  Future<void> _checkPermissionsAndGetLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoading = false);
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoading = false);
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoading = false);
      return Future.error('Location permissions are permanently denied.');
    }

    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      setState(() {
        _isLoading = false;
        // Provide the map with an initial location to render the map itself
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _selectedLocation!,
            zoom: 15.0,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error getting location: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onMapTapped(LatLng position) {
    if (widget.isReadOnly) return;
    if (_stores.isNotEmpty) return; // Only allow custom tap in delivery mode

    setState(() {
      _selectedLocation = position;
      _storeName = 'Selected Location';
      _storeAddress = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      _setupMarkers();
    });
  }

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final target = LatLng(loc.latitude, loc.longitude);

        setState(() {
          _selectedLocation = target;
          _storeName = query;
          _storeAddress = 'Search Result';
          _isSearching = false;
          _setupMarkers();
        });

        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: target, zoom: 15.0),
          ),
        );
      } else {
        setState(() => _isSearching = false);
        snackbar('No location found for "$query"', Colors.orange);
      }
    } catch (e) {
      setState(() => _isSearching = false);
      snackbar('Error searching location: $e', Colors.red);
    }
  }

  void _confirmLocation() {
    if (_selectedLocation == null || _storeName == 'Select a location') {
      snackbar('Please select a valid store location first', Colors.red);
      return;
    }
    Navigator.pop(context, {
      'name': _storeName,
      'latitude': _selectedLocation!.latitude,
      'longitude': _selectedLocation!.longitude,
    });
  }

  void _showStoreSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.of(ctx).pop();
          },
          child: DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.2,
            maxChildSize: 0.9,
            builder: (BuildContext context, ScrollController scrollController) {
              return GestureDetector(
                onTap: () {}, // Prevent taps on the white container from bubbling up
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).canvasColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Visual drag handle
                        Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12.0),
                          child: Text('Select a Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: RadioGroup<String>(
                            groupValue: _storeName,
                            onChanged: (String? value) {
                              if (value == null) return;
                              final store = _stores.firstWhere((s) => s['name'] == value);
                              Navigator.pop(ctx);
                              setState(() {
                                _selectedLocation = store['latLng'];
                                _storeName = store['name'];
                                _storeAddress = store['street'];
                                _storeHours = store['hours'];
                              });
                              _mapController?.animateCamera(
                                CameraUpdate.newCameraPosition(
                                  CameraPosition(target: store['latLng'], zoom: 15.0),
                                ),
                              ).then((_) {
                                _mapController?.showMarkerInfoWindow(MarkerId(store['id']));
                              });
                            },
                            child: ListView.separated(
                              controller: scrollController,
                              itemCount: _stores.length,
                              separatorBuilder: (context, index) => Divider(height: 1, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[200], indent: 16, endIndent: 16),
                              itemBuilder: (context, index) {
                                final store = _stores[index];
                                return RadioListTile<String>(
                                  value: store['name'],
                                  title: Text(store['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(store['street']),
                                  activeColor: Colors.lightBlue,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isReadOnly ? 'Location Map' : 'Select Location'),
      ),
      body: SafeArea(
        child: (_isLoading || _isInitialLoading)
            ? const LocationSkeleton()
            : Column(
          children: [
            Expanded(
              child: (_selectedLocation == null)
                  ? const Center(child: Text('Unable to determine location'))
                  : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation!,
                  zoom: 15.0,
                ),
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                onTap: _onMapTapped,
                style: Theme.of(context).brightness == Brightness.dark ? _darkMapStyle : null,
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                mapToolbarEnabled: true,
              ),
            ),

            if (!widget.isReadOnly && widget.stores == null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).cardColor,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for address (e.g. Ampang)',
                    suffixIcon: _isSearching
                        ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(icon: const Icon(Icons.search), onPressed: _handleSearch),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: (_) => _handleSearch(),
                ),
              ),

            // Info Panel below Map
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (widget.isReadOnly) return;
                      _showStoreSelectionBottomSheet();
                    },
                    child: Card(
                      color: Theme.of(context).cardColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.lightBlue.withValues(alpha: 0.5), width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.store, color: Colors.lightBlue),
                              title: Text(_storeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(_storeAddress),
                              trailing: widget.isReadOnly ? null : const Icon(Icons.arrow_drop_down, color: Colors.grey),
                            ),
                            if (_storeName != 'Select a location') ...[
                              const Divider(height: 1),
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.access_time, size: 20),
                                title: Text(_storeHours, style: const TextStyle(fontSize: 13)),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.isReadOnly) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_selectedLocation != null) {
                            snackbar('Routing to ${_selectedLocation!.latitude}, ${_selectedLocation!.longitude}', Colors.lightBlue);
                          }
                        },
                        icon: const Icon(Icons.navigation),
                        label: const Text('Get Directions'),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _confirmLocation,
                        icon: const Icon(Icons.check),
                        label: const Text('Confirm Location'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}