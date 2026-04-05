import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/globals.dart';
import '../../utils/snackbar_helper.dart';

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
  Set<Marker> _markers = {};
  bool _isLoading = true;
  LatLng? _selectedLocation;

  String _storeName = 'Select a location';
  String _storeAddress = 'Tap a red marker on the map';
  String _storeHours = '-';

  late List<Map<String, dynamic>> _stores;

  void _setupMarkers() {
    _markers.clear();
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
  }

  @override
  void initState() {
    super.initState();
    _stores = widget.stores ?? [
      {
        'id': 'pv13',
        'name': 'PV13',
        'street': 'Platinum Victory 13, Jalan Genting Kelang',
        'hours': 'Mon–Sun  10:00 AM – 10:00 PM',
        'latLng': const LatLng(3.2018, 101.7163),
      },
      {
        'id': 'tarumt',
        'name': 'TARUMT',
        'street': 'Tunku Abdul Rahman University, Setapak',
        'hours': 'Mon–Fri  8:00 AM – 6:00 PM',
        'latLng': const LatLng(3.2147, 101.7285),
      },
    ];

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
        desiredAccuracy: LocationAccuracy.high,
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
    // Disabled custom location mapping. User must select from the predetermined red markers or bottom list.
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12.0),
                          child: Text('Select a Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: _stores.length,
                            itemBuilder: (context, index) {
                              final store = _stores[index];
                              return RadioListTile<String>(
                                value: store['name'],
                                groupValue: _storeName,
                                title: Text(store['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(store['street']),
                                onChanged: (String? value) {
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
                              );
                            },
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
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
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                mapToolbarEnabled: true,
                onTap: _onMapTapped,
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
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.lightBlue, width: 2),
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
