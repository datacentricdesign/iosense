// Flutter side of Hub structures
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart'; // package for MQTT connection
//import 'dart:developer' as developer;

final basicURL = 'https://dwd.tudelft.nl:443/bucket/api';

class Thing {
  String id;
  String name;
  String description;
  String type;
  List<Object> properties;
  int readAt;
  String token;
  //Map<String, dynamic> keys;

  Thing(
    this.id,
    this.name,
    this.description,
    this.type,
    this.properties,
    this.readAt,
    /*this.keys*/
  );

  // named constructor from json object
  // also using an initializer list

  Thing.from_json(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    description = json['description'];
    type = json['type'];
    // taking a json input, for each object in properties
    // will place a Property into the list,  created with said object
    properties = [];
    if (json['properties'] != null) {
      for (var property_json in json['properties']) {
        properties.add(Property.from_json(property_json));
      }
    }
    readAt = json['readAt'];
  }

  // arrow notation =>x (replaces  with {return x}
  Map<String, dynamic> to_json() => {
        if (id != null) 'id': id,
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (type != null) 'type': type,
        if (properties != null) 'properties': properties,
        if (readAt != null) 'readAt': readAt,
      };

  // Given an EXISTING thing, and an access token,
  // creates a property in it of type prop_type,
  // and returns created property
  Future<Property> create_property(
      String prop_type, String access_token) async {
    if (id == null) throw Exception('Invalid thing id');
    // basic address
    var addr_url = Uri.parse('$basicURL/things/$id/properties');

    var blank = Property(
        null, prop_type.toLowerCase(), 'A simple $prop_type', prop_type);
    //blank property,except type and name
    // if it is location data

    var http_response = await http.post(addr_url,
        headers: {
          'Authorization': 'bearer $access_token',
          'Content-Type': 'application/json',
          'Response-Type': 'application/json'
        },
        body: jsonEncode(blank.to_json()));

    if (http_response.statusCode != 201) {
      // If that response was not OK, throw an error.
      throw Exception('Failed to post property to thing');
    }

    var json = jsonDecode(http_response.body);
    // adding a new property to our thing
    properties.add(Property.from_json(json));

    return (Property.from_json(json));
  }

  // updates property values given property, values and access token
  Future<void> update_property_http(
      Property property, List<dynamic> values, String access_token) async {
    var addr_url = Uri.parse(
        'https://dwd.tudelft.nl:443/bucket/api/things/$id/properties/${property.id}');

    property.values =
        values; // setting the values of the property that's replaced

    if (property.type == 'PICTURE') {
      // we must redefine
      property.values = [];
    }

    //var lala = (jsonEncode(property.to_json()));
    // printing post message
    //debugPrint(jsonEncode(property.to_json());
    if (property.type != 'PICTURE') {
      var http_response = await http.put(
        addr_url,
        headers: {
          'Authorization': 'bearer $access_token',
          'Content-Type': 'application/json',
          'Response-Type': 'application/json'
        },
        body: jsonEncode(property.to_json()),
      );

      if (http_response.statusCode != 200) {
        //TODO: replce with snackbar
        //TODO: do something with the error (retry, stop trying?)
        //error 503-> body:"upstream connect error or disconnect/reset before headers. reset reason: connection termination"
        //error 500

        // If that response was not OK, throw an error.
        // throw Exception('''Failed to post property values
        //                     ${property.values}
        //                     to property with id ${property.id},
        //                     from thing with id: $id
        //                     to the following link:
        //                     $addr_url''');
        return (true);
      }
    } else {
      // TODO: here we handle the specific media content ( picture/video )
      // wait until http is redefined
    }
    return (true);
    //var json =  await jsonDecode(http_response.body);
    //return(Property.from_json(json));
  }

  // TODO: - debug and fix authorization of MQTT on the bucket side

  void update_property_mqtt(Property property, List<dynamic> values,
      String thing_token, MqttClient mqtt_client) {
    var topic_url = '/things/$id/properties/${property.id}';

    // struct of data to send to server value :[[ tmstamp, ... ]]
    var temp = <Object>[];
    // if four dimensions, timestamp is given by last value
    temp.add((property.type == 'FOUR_DIMENSIONS')
        ? (values[4].millisecondsSinceEpoch)
        : DateTime.now().millisecondsSinceEpoch);
    temp +=
        (property.type != 'FOUR_DIMENSIONS') ? values : values.sublist(0, 4);
    property.values =
        temp; // setting the values of the property that's replaced

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(property.to_json()));

    if (mqtt_client.connectionStatus.state == MqttConnectionState.connected) {
      mqtt_client.publishMessage(
          topic_url, MqttQos.exactlyOnce, builder.payload);
    }
  }

  // Creates properties in hub that thing uses
  //TODO:
  // - check the actual properties this thing has and create when needed
  void create_properties_hub(String access_token) async {
    // Sequential creation of properties (they are always in the same order)
    //if (properties.isEmpty) {
    await create_property('GYROSCOPE', access_token);
    await create_property('ACCELEROMETER', access_token);
    //}
    // 5D location property vector
    //await create_property('FOUR_DIMENSIONS', access_token);
    // 5D vector -> location (2D) and altitude (1D)
    await create_property('LOCATION', access_token);
    await create_property('ALTITUDE', access_token);

    // Picture/ video property
    await create_property('PICTURE', access_token);
  }
}

// supported types so far : ACCELEROMETER, GYROSCOPE, 5_DIMENSIONS, IMAGE
class Property {
  String id;
  String name;
  String description;
  String type;
  List<dynamic> values; //list of values

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
        if (id != null) 'id': id,
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (type != null) 'typeId': type,
        if (values != null) 'values': [values],
      };
}

// client of DCD,
// used to receive token, connect and interact with the hub.
// ignore: camel_case_types
class DCD_client {
  final authorization_endpoint =
      Uri.parse('https://dwd.tudelft.nl/oauth2/auth');
  final token_endpoint = Uri.parse('https://dwd.tudelft.nl/oauth2/token');
  final id = 'clients:iosense';

  // This is a URL on your application's server. The authorization server
  // will redirect the resource owner here once they've authorized the
  // client. The redirection will include the authorization code in the
  // query parameters.
  final redirect_url = Uri.parse('nl.tudelft.ide.iosense:/oauth2redirect');

  String access_token; // holds access token for our hub connection
  Thing thing; // holds thing for our client to update

  bool authorized = false;

  // default constructor
  DCD_client();

  Future<Thing> FindOrCreateThing(
      String thing_name, String access_token) async {
    var addr_url = Uri.parse(basicURL + '/things');
    // creating empty thing
    var http_response = await http.get(addr_url, headers: {
      'Authorization': 'bearer $access_token',
      'Content-Type': 'application/json',
      'Response-Type': 'application/json'
    });

    //TODO: implment a check if the Thing was created
    // if (http_response.statusCode != 201 ||
    //     http_response.statusCode != 200 ||
    //     http_response.statusCode != 202) {
    //   // If that response was not OK, throw an error.
    //   throw Exception('Failed to post to thing');
    // }

    Iterable l = json.decode(http_response.body);
    var things = List<Thing>.from(l.map((model) => Thing.from_json(model)));
    //check the JSON file for a thing with the same name
    things.forEach((element) {
      if (element.name == thing_name) {
        thing = element;
        return element;
      }
    });

    if (thing == null) {
      // if we don't find the thing, create it
      return await create_thing(thing_name, access_token);
    }
  }

  // creates thing in hub and puts it into client thing member
  Future<Thing> create_thing(String thing_name, String access_token) async {
    var addr_url = Uri.parse(basicURL + '/things');
    // creating empty thing
    var blank = Thing(null, thing_name, null, 'test', null, null);
    var http_response = await http.post(
      addr_url,
      headers: {
        'Authorization': 'bearer $access_token',
        'Content-Type': 'application/json',
        'Response-Type': 'application/json'
      },
      body: jsonEncode(blank.to_json()),
    );

    if (http_response.statusCode != 201) {
      // If that response was not OK, throw an error.
      throw Exception('Failed to post to thing');
    }

    var json = jsonDecode(http_response.body);
    thing = Thing.from_json(json);
    thing.create_properties_hub(access_token);
    return (thing);
  }

  // structure for  deleting all things in hub
  void delete_things_hub(List<String> ids_to_delete) {
    ids_to_delete.forEach((prop_id_to_delete) async {
      var http_response = await http.delete(
          Uri.parse('https://dwd.tudelft.nl/api/things/$prop_id_to_delete'),
          headers: {'Authorization': 'bearer $access_token'});
    });
  }
}
