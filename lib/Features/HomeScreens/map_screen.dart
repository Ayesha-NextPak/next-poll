import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  
  LatLng _selectedPosition = const LatLng(37.4219999, -122.0840575);
  Future<void> _locateMe()async
  {
    var status = await Permission.location.request();
    if(status.isGranted)
    {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      LatLng newPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedPosition = newPos;

      });
      mapController?.animateCamera(CameraUpdate.newLatLngZoom(newPos, 15));
    }else
    {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission is denied')));
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick a location'),),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: _selectedPosition, zoom: 14),
        onMapCreated: (controller)=> mapController = controller,
        markers: {
          Marker(markerId: const MarkerId('selected'), position: _selectedPosition
          )
        },
        onTap: (latlng)
        {
          setState(() {
            _selectedPosition = latlng;
          });
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'locate_me',
            onPressed: _locateMe,
          backgroundColor: Colors.orange,
          child: const Icon(Icons.my_location),
          ),
          FloatingActionButton(
            heroTag: 'confirm_locations',
            onPressed: (){Navigator.pop(context, _selectedPosition);},
          backgroundColor: Colors.orange,
          child: const Icon(Icons.check),
          )
        ],
      ),
    );
  }
}