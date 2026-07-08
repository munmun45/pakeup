/// Interactive Google Maps HTML for WebView (search + pin select).
/// Same as pakeup_admin partner map picker.
String buildGoogleMapsPickerHtml(
  String apiKey, {
  double? latitude,
  double? longitude,
}) {
  final lat = latitude ?? 20.5937;
  final lng = longitude ?? 78.9629;
  final zoom = latitude != null && longitude != null ? 16 : 5;

  return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <style>
    html, body { margin: 0; padding: 0; height: 100%; overflow: hidden; font-family: Segoe UI, Arial, sans-serif; }
    #search-box { padding: 10px 12px; background: #fff; border-bottom: 1px solid #e8e0e5; }
    #pac-input {
      width: 100%; box-sizing: border-box; padding: 12px 14px;
      border: 1px solid #e8e0e5; border-radius: 10px; font-size: 14px; outline: none;
    }
    #pac-input:focus { border-color: #e91e8c; }
    #map { height: calc(100% - 62px); width: 100%; }
  </style>
  <script>
    let map, marker, geocoder, autocomplete;

    function sendLocation(payload) {
      var str = JSON.stringify(payload);
      if (window.LocationChannel && LocationChannel.postMessage) {
        LocationChannel.postMessage(str);
      }
    }

    function parseAddress(components) {
      var r = { city: '', state: '', pincode: '' };
      (components || []).forEach(function(c) {
        if (c.types.indexOf('locality') >= 0) r.city = c.long_name;
        if (c.types.indexOf('administrative_area_level_1') >= 0) r.state = c.long_name;
        if (c.types.indexOf('postal_code') >= 0) r.pincode = c.long_name;
        if (!r.city && c.types.indexOf('sublocality_level_1') >= 0) r.city = c.long_name;
      });
      return r;
    }

    function emitFromLatLng(latLng, formattedAddress) {
      geocoder.geocode({ location: latLng }, function(results, status) {
        var address = formattedAddress || '';
        var parsed = { city: '', state: '', pincode: '' };
        if (status === 'OK' && results && results[0]) {
          address = results[0].formatted_address;
          parsed = parseAddress(results[0].address_components);
        }
        sendLocation({
          lat: latLng.lat(),
          lng: latLng.lng(),
          address: address,
          city: parsed.city,
          state: parsed.state,
          pincode: parsed.pincode
        });
      });
    }

    function initMap() {
      var center = { lat: $lat, lng: $lng };
      map = new google.maps.Map(document.getElementById('map'), {
        zoom: $zoom,
        center: center,
        mapTypeControl: false,
        streetViewControl: false,
        fullscreenControl: false,
        scrollwheel: true,
        gestureHandling: 'greedy'
      });
      marker = new google.maps.Marker({ map: map, position: center, draggable: true });
      geocoder = new google.maps.Geocoder();

      var input = document.getElementById('pac-input');
      autocomplete = new google.maps.places.Autocomplete(input, {
        componentRestrictions: { country: 'in' },
        fields: ['geometry', 'formatted_address', 'address_components']
      });
      autocomplete.bindTo('bounds', map);

      autocomplete.addListener('place_changed', function() {
        var place = autocomplete.getPlace();
        if (!place.geometry || !place.geometry.location) return;
        map.setCenter(place.geometry.location);
        map.setZoom(16);
        marker.setPosition(place.geometry.location);
        var p = parseAddress(place.address_components);
        sendLocation({
          lat: place.geometry.location.lat(),
          lng: place.geometry.location.lng(),
          address: place.formatted_address || '',
          city: p.city,
          state: p.state,
          pincode: p.pincode
        });
      });

      marker.addListener('dragend', function() { emitFromLatLng(marker.getPosition()); });
      map.addListener('click', function(e) {
        marker.setPosition(e.latLng);
        emitFromLatLng(e.latLng);
      });

      emitFromLatLng(marker.getPosition());
    }
  </script>
  <script async defer
    src="https://maps.googleapis.com/maps/api/js?key=$apiKey&libraries=places&callback=initMap">
  </script>
</head>
<body>
  <div id="search-box">
    <input id="pac-input" type="text" placeholder="Search address or place..." />
  </div>
  <div id="map"></div>
</body>
</html>
''';
}
