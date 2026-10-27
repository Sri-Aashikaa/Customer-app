import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

const kGreen = Color(0xFF059669);
const String kGoogleMapsApiKey = 'AIzaSyBDy9hy20F8UTS8URDJfDMrQeXQOoSpNH4';

class LocationPickerDialog extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final String initialArea;
  final String initialCity;
  final String initialPincode;
  final String initialAddress;

  const LocationPickerDialog({
    super.key,
    this.initialLat = 13.0827,
    this.initialLng = 80.2707,
    this.initialArea = 'Anna Nagar',
    this.initialCity = 'Chennai',
    this.initialPincode = '600040',
    this.initialAddress = '',
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    double initialLat = 13.0827,
    double initialLng = 80.2707,
    String initialArea = 'Anna Nagar',
    String initialCity = 'Chennai',
    String initialPincode = '600040',
    String initialAddress = '',
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 620,
          height: 680,
          child: LocationPickerDialog(
            initialLat: initialLat,
            initialLng: initialLng,
            initialArea: initialArea,
            initialCity: initialCity,
            initialPincode: initialPincode,
            initialAddress: initialAddress,
          ),
        ),
      ),
    );
  }

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  final MapController _mapController = MapController();
  late LatLng _currentLocation;
  double _zoom = 15.5;

  // Google Maps layer mode: 'm' = Roadmap, 'y' = Satellite Hybrid, 'p' = Terrain
  String _mapType = 'm';

  late TextEditingController _areaCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _pincodeCtrl;
  late TextEditingController _addressCtrl;
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isLocating = false;
  bool _isGeocoding = false;
  bool _isSearching = false;
  String _statusMessage = 'Tap anywhere on Google Maps to pin your delivery address';

  final List<Map<String, dynamic>> _quickLocations = [
    {'name': 'Anna Nagar', 'lat': 13.0878, 'lng': 80.2170, 'pincode': '600040'},
    {'name': 'T. Nagar', 'lat': 13.0418, 'lng': 80.2341, 'pincode': '600017'},
    {'name': 'Adyar', 'lat': 13.0012, 'lng': 80.2565, 'pincode': '600020'},
    {'name': 'Velachery', 'lat': 12.9815, 'lng': 80.2180, 'pincode': '600042'},
    {'name': 'Kilpauk', 'lat': 13.0784, 'lng': 80.2437, 'pincode': '600010'},
    {'name': 'Mylapore', 'lat': 13.0368, 'lng': 80.2676, 'pincode': '600004'},
    {'name': 'Porur', 'lat': 13.0382, 'lng': 80.1565, 'pincode': '600116'},
    {'name': 'Tambaram', 'lat': 12.9249, 'lng': 80.1000, 'pincode': '600045'},
  ];

  @override
  void initState() {
    super.initState();
    _currentLocation = LatLng(
      widget.initialLat != 0.0 ? widget.initialLat : 13.0827,
      widget.initialLng != 0.0 ? widget.initialLng : 80.2707,
    );

    _areaCtrl = TextEditingController(text: widget.initialArea);
    _cityCtrl = TextEditingController(text: widget.initialCity);
    _pincodeCtrl = TextEditingController(text: widget.initialPincode);
    _addressCtrl = TextEditingController(text: widget.initialAddress);

    // Initial reverse geocode if location is provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialAddress.isEmpty) {
        _reverseGeocode(_currentLocation);
      }
    });
  }

  @override
  void dispose() {
    _areaCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _addressCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Center and zoom to device's live GPS position
  Future<void> _fetchCurrentGPS() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        final newPoint = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _currentLocation = newPoint;
          _statusMessage = 'GPS Position detected';
        });
        _mapController.move(newPoint, 17.0);
        await _reverseGeocode(newPoint);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied. Please pick your spot on the map.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not fetch GPS: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// Search place/address via Google Geocoding API
  Future<void> _searchAddress(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() => _isSearching = true);
    FocusScope.of(context).unfocus();

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(q)}&key=$kGoogleMapsApiKey',
      );
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          final geom = first['geometry'] as Map<String, dynamic>?;
          final loc = geom?['location'] as Map<String, dynamic>?;
          if (loc != null) {
            final lat = (loc['lat'] as num).toDouble();
            final lng = (loc['lng'] as num).toDouble();
            final targetPoint = LatLng(lat, lng);

            setState(() {
              _currentLocation = targetPoint;
              _zoom = 16.5;
            });
            _mapController.move(targetPoint, 16.5);
            await _parseGoogleGeocodeResult(first, targetPoint);
            return;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No location found for "$q". Try another landmark or area name.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  /// Reverse geocode coordinates using Google Maps Geocoding API
  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isGeocoding = true);
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${point.latitude},${point.longitude}&key=$kGoogleMapsApiKey',
      );
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          await _parseGoogleGeocodeResult(first, point);
          return;
        }
      }
      // Secondary fallback to OpenStreetMap if Google returns empty
      await _fallbackReverseGeocode(point);
    } catch (_) {
      await _fallbackReverseGeocode(point);
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  /// Parse address components from Google Geocoding response
  Future<void> _parseGoogleGeocodeResult(Map<String, dynamic> first, LatLng point) async {
    final formattedAddress = (first['formatted_address'] ?? '').toString();
    final components = (first['address_components'] as List<dynamic>?) ?? [];

    String? detectedArea;
    String? detectedCity;
    String? detectedPincode;
    String? detectedStreet;

    for (final comp in components) {
      final c = comp as Map<String, dynamic>;
      final types = (c['types'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? [];
      final longName = (c['long_name'] ?? '').toString();

      if (types.contains('sublocality_level_1') ||
          types.contains('sublocality') ||
          types.contains('neighborhood')) {
        detectedArea ??= longName;
      } else if (types.contains('locality') || types.contains('administrative_area_level_2')) {
        detectedCity ??= longName;
      } else if (types.contains('postal_code')) {
        detectedPincode = longName;
      } else if (types.contains('route') || types.contains('premise') || types.contains('street_number')) {
        detectedStreet = detectedStreet == null ? longName : '$longName, $detectedStreet';
      }
    }

    if (mounted) {
      setState(() {
        if (detectedArea != null && detectedArea.isNotEmpty) {
          _areaCtrl.text = detectedArea;
        }
        if (detectedCity != null && detectedCity.isNotEmpty) {
          _cityCtrl.text = detectedCity;
        }
        if (detectedPincode != null && detectedPincode.isNotEmpty) {
          _pincodeCtrl.text = detectedPincode;
        }
        if (formattedAddress.isNotEmpty) {
          _addressCtrl.text = formattedAddress;
        }
        _statusMessage = '📍 ${_areaCtrl.text}, ${_cityCtrl.text} (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
      });
    }
  }

  /// Fallback reverse geocoding via Nominatim
  Future<void> _fallbackReverseGeocode(LatLng point) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1',
      );
      final resp = await http.get(url, headers: {'User-Agent': 'AmudhamRawMilkCustomerApp/1.0'});
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null && mounted) {
          final suburb = address['suburb'] ?? address['neighbourhood'] ?? address['residential'] ?? address['quarter'];
          final city = address['city'] ?? address['town'] ?? address['state_district'] ?? 'Chennai';
          final postcode = address['postcode'] ?? '600040';
          final road = address['road'] ?? address['pedestrian'] ?? address['commercial'] ?? '';

          setState(() {
            if (suburb != null) _areaCtrl.text = suburb.toString();
            _cityCtrl.text = city.toString();
            _pincodeCtrl.text = postcode.toString();
            if (_addressCtrl.text.trim().isEmpty && road.isNotEmpty) {
              _addressCtrl.text = road.toString();
            }
            _statusMessage = '📍 ${_areaCtrl.text}, ${_cityCtrl.text}';
          });
        }
      }
    } catch (_) {
      // Keep existing manual inputs if network fails
    }
  }

  void _onMapTapped(TapPosition tapPos, LatLng point) {
    setState(() {
      _currentLocation = point;
      _statusMessage = 'Pinned: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
    });
    _mapController.move(point, _zoom);
    _reverseGeocode(point);
  }

  /// Open external Google Maps to verify pinned location
  Future<void> _openExternalGoogleMaps() async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${_currentLocation.latitude},${_currentLocation.longitude}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _confirmAndReturn() {
    Navigator.of(context).pop({
      'latitude': _currentLocation.latitude,
      'longitude': _currentLocation.longitude,
      'area': _areaCtrl.text.trim().isNotEmpty ? _areaCtrl.text.trim() : 'Anna Nagar',
      'city': _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : 'Chennai',
      'pincode': _pincodeCtrl.text.trim().isNotEmpty ? _pincodeCtrl.text.trim() : '600040',
      'address': _addressCtrl.text.trim(),
      'location': '${_areaCtrl.text.trim()}, ${_cityCtrl.text.trim()}'.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.place, color: kGreen, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Google Maps Location',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text(
                  'Pin delivery address & drop point',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 20),
            tooltip: 'Open in Google Maps App',
            onPressed: _openExternalGoogleMaps,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(null),
          ),
        ],
        elevation: 1,
      ),
      body: Column(
        children: [
          // ── 1. GOOGLE PLACES / ADDRESS SEARCH BAR ────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _searchAddress,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search place, street, or landmark in Google Maps...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF475569)),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: _isSearching ? null : () => _searchAddress(_searchCtrl.text),
                  child: _isSearching
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Search', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // ── 2. QUICK PRESET CHENNAI AREAS ────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Quick Areas:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(width: 8),
                  ..._quickLocations.map((loc) {
                    final isSelected = _areaCtrl.text.toLowerCase() == loc['name'].toString().toLowerCase();
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(loc['name']),
                        avatar: Icon(Icons.place, size: 14, color: isSelected ? Colors.white : kGreen),
                        backgroundColor: isSelected ? kGreen : Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF1E293B),
                        ),
                        side: BorderSide(color: isSelected ? kGreen : const Color(0xFFE2E8F0)),
                        onPressed: () {
                          final point = LatLng(loc['lat'], loc['lng']);
                          setState(() {
                            _currentLocation = point;
                            _areaCtrl.text = loc['name'];
                            _pincodeCtrl.text = loc['pincode'];
                            _statusMessage = 'Area set to ${loc['name']}';
                          });
                          _mapController.move(point, 16.0);
                          _reverseGeocode(point);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // ── 3. INTERACTIVE GOOGLE MAP CANVAS ──────────────────────────────
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation,
                    initialZoom: _zoom,
                    onTap: _onMapTapped,
                    onPositionChanged: (pos, hasGesture) {
                      _zoom = pos.zoom;
                    },
                  ),
                  children: [
                    // Official Google Maps Tile Layer
                    TileLayer(
                      key: ValueKey('google_tile_layer_$_mapType'),
                      urlTemplate:
                          'https://mt{s}.google.com/vt/lyrs=$_mapType&x={x}&y={y}&z={z}&key=$kGoogleMapsApiKey',
                      subdomains: const ['0', '1', '2', '3'],
                      userAgentPackageName: 'com.amudham.rawmilk',
                      maxZoom: 20,
                      maxNativeZoom: 20,
                    ),

                    // Centered Drop Pin Marker
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentLocation,
                          width: 60,
                          height: 60,
                          child: const Column(
                            children: [
                              Icon(Icons.location_pin, size: 48, color: Color(0xFFDC2626)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Floating Top Status Notification Banner
                Positioned(
                  top: 10,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        if (_isGeocoding)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: kGreen),
                          )
                        else
                          const Icon(Icons.touch_app, size: 16, color: kGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Google Watermark / Attribution (Bottom Left)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Google',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4285F4),
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Maps',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5F6368),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Floating Google Map Controls: Layer Switcher, GPS, Zoom (Right)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(
                    children: [
                      // Google Maps Layer Toggle (Roadmap vs Satellite)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: PopupMenuButton<String>(
                          tooltip: 'Switch Google Map Layer',
                          initialValue: _mapType,
                          icon: Icon(
                            _mapType == 'y' ? Icons.satellite_alt : Icons.layers_outlined,
                            color: const Color(0xFF0F172A),
                            size: 20,
                          ),
                          onSelected: (val) {
                            setState(() => _mapType = val);
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'm',
                              child: Row(
                                children: [
                                  Icon(Icons.map, size: 18, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Roadmap (Default)', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'y',
                              child: Row(
                                children: [
                                  Icon(Icons.satellite_alt, size: 18, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Satellite Hybrid', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'p',
                              child: Row(
                                children: [
                                  Icon(Icons.terrain, size: 18, color: Colors.brown),
                                  SizedBox(width: 8),
                                  Text('Terrain', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // GPS Current Location Button
                      FloatingActionButton.small(
                        heroTag: 'gps_btn',
                        backgroundColor: Colors.white,
                        foregroundColor: kGreen,
                        tooltip: 'Center on My GPS Location',
                        onPressed: _isLocating ? null : _fetchCurrentGPS,
                        child: _isLocating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: kGreen),
                              )
                            : const Icon(Icons.my_location),
                      ),
                      const SizedBox(height: 8),

                      // Zoom In
                      FloatingActionButton.small(
                        heroTag: 'zoom_in_btn',
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        onPressed: () {
                          _zoom = (_zoom + 1).clamp(3.0, 20.0);
                          _mapController.move(_currentLocation, _zoom);
                        },
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 6),

                      // Zoom Out
                      FloatingActionButton.small(
                        heroTag: 'zoom_out_btn',
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        onPressed: () {
                          _zoom = (_zoom - 1).clamp(3.0, 20.0);
                          _mapController.move(_currentLocation, _zoom);
                        },
                        child: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 4. BOTTOM ADDRESS DETAILS & CONFIRMATION SHEET ────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Area, City, and Pincode Fields
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _areaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Area / Neighborhood *',
                          prefixIcon: Icon(Icons.location_city_outlined, size: 18),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _cityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'City *',
                          prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _pincodeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Pincode',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Street / Full Address Field
                TextField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Flat / Door No. & Street Address (Auto-filled from Google Maps)',
                    prefixIcon: Icon(Icons.home_outlined, size: 18),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Confirm Button
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text(
                    'Confirm Delivery Location ✓',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _confirmAndReturn,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
