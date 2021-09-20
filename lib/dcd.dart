// Flutter side of Hub structures
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:provider/provider.dart';

////// this DCD file needs extensive reworking
///TODO:
/// - add mqtt client
/// - fix null checking
/// - add error handling
/// - add logging
/// - improve documentation
///

// this URL should point to the bucket API!
const basicURL = 'https://dwd.tudelft.nl:443/bucket/api';

String? _accessToken;
String? _refreshToken;

String getAccessToken([String? newAccessToken]) {
  /// returns the access token, either the one passed or the one DCD has
  /// checks if the token is "fresh"
  ///
  ///

  var finalToken = '';
  // if we're not passed a new access token,
  if (newAccessToken == null) {
    //make sure we got one when constructed
    if (_accessToken == null) {
      // we don't have an access token
      // and that's okay?
      // TODO: demystify this code
    } else {
      finalToken = _accessToken!;
    } //use the one we have
  } else {
    //we've received a new access token, update the global one
    _accessToken = newAccessToken;
  }

  return finalToken;
}

Map<String, String> httpHeaders([String? newAccessToken]) {
  /// returns the headers for the http request, checking the access token first

  var token = getAccessToken(newAccessToken);
  return ({
    'Authorization': 'bearer $token',
    'Content-Type': 'application/json',
    'Response-Type': 'application/json'
  });
}

class Thing extends ChangeNotifier {
  String id = '';
  String name = '';
  String description = '';
  String type = '';
  List<Property>? properties;
  int? readAt;
  //Map<String, dynamic> keys;

  String latestError = '';
  String lastMessageToSend = '';

  Thing(this.id, this.name, this.description, this.type, this.properties,
      this.readAt);

  // named constructor from json object
  // also using an initializer list

  Thing.from_json(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    description = json['description'];
    type = json['type'];
    properties = [];
    if (json['properties'] != null) {
      for (var propertyJson in json['properties']) {
        properties!.add(Property.from_json(propertyJson));
      }
    }
    readAt = json['readAt'];
  }

  // arrow notation =>x (replaces  with {return x}
  Map<String, dynamic> to_json() => {
        'id': id,
        'name': name,
        'description': description,
        'type': type,
        'properties': properties,
        'readAt': readAt ?? 0,
      };

  Future<Property> createProperty(String propType,
      [String? newAccessToken]) async {
    /// Given an EXISTING thing,
    /// creates a property in it of type prop_type,
    /// and returns created property
    ///
    if (id == '') throw Exception('Invalid thing id');

    // basic address
    var addrUrl = Uri.parse('$basicURL/things/$id/properties');

    // create a blank property
    var blank =
        Property(null, propType.toLowerCase(), 'A simple $propType', propType);

    // 'post' the blank property to the server
    var httpResponse = await http.post(addrUrl,
        headers: httpHeaders(newAccessToken),
        body: jsonEncode(blank.to_json()));

    if (httpResponse.statusCode != 201) {
      // If that response was not OK, throw an error.
      throw Exception('Failed to post property to thing');
    }

    // create the new property from the server response
    var newProperty = Property.from_json(jsonDecode(httpResponse.body));

    // adding a new property to our thing
    properties!.add(newProperty);

    return (newProperty);
  }

  // updates property values given property, values and access token
  Future<void> update_property_http(Property property, List<dynamic> values,
      [String? accessToken]) async {
    var addrUrl = Uri.parse('$basicURL/things/$id/properties/${property.id}');

    property.values = [DateTime.now().millisecondsSinceEpoch];
    for (var element in values) {
      property.values!.add(element);
    }
    lastMessageToSend = property.to_json().toString();

    var httpResponse = await http.put(addrUrl,
        headers: httpHeaders(accessToken),
        body: jsonEncode(property.to_json()));

    if (httpResponse.statusCode != 200 && httpResponse.statusCode != 204) {
      latestError =
          'Failed to post property values ${property.values} to property with id ${property.id}, from thing with id: $id to the following response: ${httpResponse.statusCode}';
      notifyListeners();
    }
    return (null);
  }

  Future<List<Property>?> getProperties() async {
    properties = [];
    var addrUrl = Uri.parse(basicURL + '/things/' + id + '/properties');
    // creating empty thing
    var httpResponse = await http.get(addrUrl, headers: httpHeaders());
    if (httpResponse.statusCode != 200 && httpResponse.statusCode != 204) {
      latestError =
          'Failed to gather properties from thing with id: $id to the following response: ${httpResponse.statusCode}';
    } else {
      var json = jsonDecode(httpResponse.body);
      for (var propertyJson in json['jsonProperty']) {
        properties!.add(Property.from_json(propertyJson));
      }
    }
    return properties;
  }

  void createPropertiesHub([String? accessToken]) async {
    /// creates the properties that is expected of a phone
    await createProperty('GYROSCOPE', accessToken);
    await createProperty('ACCELEROMETER', accessToken);
    await createProperty('LOCATION', accessToken);
    await createProperty('MagneticField', accessToken);
  }

  bool updatePropertyByName(String name, List<dynamic> values) {
    /// updates property values given the property's name and new values values
    /// returns true if successful (item found)
    /// returns false if unsuccessful (item not found)
    ///
    /// TODO: verify the proerty was updated
    ///

    var updated = false;
    name = name.toLowerCase();

    for (var property in properties!) {
      if (property.name!.toLowerCase() == name) {
        update_property_http(property, values);
        updated = true;
      }
    }
    return updated;
  }
}

// supported types so far : ACCELEROMETER, GYROSCOPE, 5_DIMENSIONS, IMAGE
class Property {
  String? id;
  String? name;
  String? description;
  String? type;
  List<dynamic>? values; //list of values

  Property(this.id, this.name, this.description, this.type);

  // named constructor from json object
  // also using an initializer list
  Property.from_json(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        description = json['description'],
        type = json['typeId'],
        values = json['values'];

  // overriding function for jsonEncode Call
  Map<String, dynamic> toJson() => to_json();

  // arrow notation (replaces {return x;}
  Map<String, dynamic> to_json() => {
        // only create fields of json is value is not null
        'id': id ?? '',
        'name': name ?? '',
        'description': description ?? '',
        'typeId': type ?? '',
        'values': [values],
      };
}

// client of DCD,
// used to receive token, connect and interact with the hub.
// ignore: camel_case_types
class DCD_client extends ChangeNotifier {
  final authorizationEndpoint = Uri.parse('https://dwd.tudelft.nl/oauth2/auth');
  final id = 'clients:iosense';

  // This is a URL on your application's server. The authorization server
  // will redirect the resource owner here once they've authorized the
  // client. The redirection will include the authorization code in the
  // query parameters.
  final redirectUrl = Uri.parse('nl.tudelft.ide.iosense:/oauth2redirect');

  final List<String> _scopes = [
    'openid',
    'offline',
    'email',
    'profile',
    'dcd:public',
    'dcd:things',
    'dcd:properties'
  ];

  Thing thing = Thing('', '', '', '', [], 0); // holds a blank thing
  late List<Thing> allThings; // holds a list of things
  bool authorized = false;
  String latestError = '';
  // default constructor
  DCD_client() {
    //when starting up, check if we have a stored token!
    _checkStoredToken();
  }

  // app authentication object
  final FlutterAppAuth _appAuth = FlutterAppAuth();

  Future<Thing?> FindOrCreateThing(String thingName) async {
    /// checks the "things" associated with the user
    /// returns the first "thing" with a matching name
    /// or creates that thing

    //make sure we got one when constructed
    getAccessToken();
    //use the one we have

    var addrUrl = Uri.parse(basicURL + '/things');

    var httpResponse = await http.get(addrUrl, headers: httpHeaders());

    Iterable l = json.decode(httpResponse.body);
    allThings = List<Thing>.from(l.map((model) => Thing.from_json(model)));
    //check the JSON file for a thing with the same name
    var targetThing = Thing('', '', '', '', null, null);
    for (var thingElement in allThings) {
      if (thingElement.name == thingName) {
        targetThing = thingElement;
      }
    }

    if (targetThing.name == '') {
      // if we don't find the thing, create it
      targetThing = (await createThing(thingName))!;
    }
    thing = targetThing;
    notifyListeners();
    return (targetThing);
  }

  // creates thing in hub and puts it into client thing member
  Future<Thing?> createThing(String thingName, [String? accessToken]) async {
    // check to make sure we have the access token

    var uri = Uri.parse(basicURL + '/things');
    // creating empty thing
    var blank = Thing('', thingName, '', 'test', null, null);

    // post it to the server
    var httpResponse = await http.post(
      uri,
      headers: httpHeaders(accessToken),
      body: jsonEncode(blank.to_json()),
    );

    if (httpResponse.statusCode != 201) {
      // If that response was not OK, throw an error.
      latestError = 'Failed to post thing';
      throw Exception('Failed to post to thing');
    }

    thing = Thing.from_json(jsonDecode(httpResponse.body));

    // since we always created the same properties on the thing (at least....)
    // we can just create the general properties from the thing
    // thing.createPropertiesHub(accessToken!);
    thing.createPropertiesHub();
    notifyListeners();
    return (thing);
  }

  Future<void> _getAndStoreToken() async {
    var result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(id, redirectUrl.toString(),
            discoveryUrl:
                'https://dwd.tudelft.nl/.well-known/openid-configuration',
            scopes: _scopes));
    if (result != null) {
      authorized = true;
      _accessToken = result.accessToken;
      _refreshToken = result.refreshToken;
      await _storeToken(_accessToken, _refreshToken);

      // TODO simplify the flow and have a get thing check
      await FindOrCreateThing('iosensephone');
    }
  }

  Future<void> _storeToken(
      [String? _accessToken, String? _refreshToken]) async {
    /// stores the tokens in shared prefs
    /// clears if no strings passed
    var prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', _accessToken ?? '');
    await prefs.setString('refreshToken', _refreshToken ?? '');
  }

  Future<bool> _checkStoredToken() async {
    /// Grabs token from SharedPreferences (if avalible)
    /// sets authorized and access token
    /// returns true if token is loaded
    /// returns false if no token is stored
    var prefs = await SharedPreferences.getInstance();
    var storedToken = prefs.getString('accessToken');
    if (storedToken == null || storedToken == '') {
      // we do not have a token!
    } else {
      // this means we have a stored token and should set our token as that!
      getAccessToken(storedToken);
      authorized = true;

      // TODO: simplify the flow and only find or create thing once!
      await FindOrCreateThing('iosensephone');
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> checkAuthorized() async {
    /// checks the current authorization of the user by pinging the server
    /// TODO: make this function work
    return true;
  }

  Future<bool> authorize() async {
    /// This function authorizes the user
    if (authorized) {
      // we should be authorized, let's "log out"
      authorized = false;
      await _storeToken();
    } else {
      // check if we have saved a token
      var prefs = await SharedPreferences.getInstance();
      var storedToken = prefs.getString('accessToken');

      if (storedToken == null || storedToken == '') {
        // if the token is empty or null, get a new one
        await _getAndStoreToken();
        authorized = true;
      } else {
        // TODO: check the validity of the token
        _accessToken = storedToken;
        authorized = true;
      }
    }

    notifyListeners();
    // result is null, so something when wrong
    return false;
  }
}
