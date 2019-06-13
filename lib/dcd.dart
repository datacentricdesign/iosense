// Flutter side of Hub structures
import 'dart:convert';

import 'package:http/http.dart' as http;


class Thing
{
  String id;
  String name;
  String description;
  String type;
  List<dynamic> properties;
  int readAt;
  //Map<String, dynamic> keys;

  Thing(this.id,
        this.name,
        this.description,
        this.type,
        this.properties,
        this.readAt,
        /*this.keys*/);

  // named constructor from json object
  // also using an initializer list
  Thing.from_json(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        description = json['description'],
        type = json['type'],
        properties = json['properties'],
        readAt = json['readAt']
        /*keys =  json['keys']*/;

  // arrow notation (replaces {return x;}
  Map<String, dynamic> to_json() =>
      {
        'id': id,
        'name': name,
        'description': description,
        'type': type,
        'properties': properties,
        'readAt': readAt,
        /*'keys': keys,*/
      };

  // Given an EXISTING thing, an access token, and values
  //updates a property in it of type prop_type
  Future<Property> create_property(String prop_type, String access_token) async
  {
    var addr_url = 'https://dwd.tudelft.nl/api/things/${this.id}/properties';
    //blank property,except type
    Property blank = Property(null, null, null, prop_type);

    var http_response = await http.post(addr_url,
                                        headers: {'Authorization':
                                                  'Bearer ${access_token}'},
                                        body: blank.to_json());

    if (http_response.statusCode != 200)
    {
      // If that response was not OK, throw an error.
      throw Exception('Failed to post property to thing');
    }

    var json = jsonDecode(http_response.body);
    return(Property.from_json(json));
  }

  // updates property values given property, values and access token
  Future<void>update_property(Property property , List<dynamic> values, String access_token) async
  {
    var addr_url = 'https://dwd.tudelft.nl/api/things/${this.id}/properties/${property.id}';
    property.values = values; // setting the values of the property that's replaced
    var http_response = await http.post(addr_url,
                                        headers: {'Authorization':
                                        'Bearer ${access_token}'},
                                        body: property.to_json());

    if (http_response.statusCode != 200)
    {
      // If that response was not OK, throw an error.
      throw Exception('Failed to post property to thing');
    }

    var json = jsonDecode(http_response.body);
    return(Property.from_json(json));
  }

}


// supported types so far : ACCELEROMETER, GYROSCOPE
class Property
{
  String id;
  String name;
  String description;
  String type;
  List<dynamic> values; //list of values

  Property(this.id,
           this.name,
           this.description,
           this.type);

  // named constructor from json object
  // also using an initializer list
  Property.from_json(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        description = json['description'],
        type = json['type'],
        values= json['values'];

  // arrow notation (replaces {return x;}
  Map<String, dynamic> to_json() =>
      {
        'id': id,
        'name': name,
        'description': description,
        'type': type,
        'values':values,
      };
}



List<dynamic> Properties;
// client of DCD,
// used to receive token, connect and interact with the hub.
class DCD_client {
  final authorization_endpoint =
  Uri.parse('https://dwd.tudelft.nl/oauth2/auth');
  final token_endpoint =
  Uri.parse('https://dwd.tudelft.nl/oauth2/token');
  final id = 'dcd-mobile-app';
  //final secret = 'BZ2y0LDdoGxGqSHBS_0-Dm6wyz';

  // This is a URL on your application's server. The authorization server
  // will redirect the resource owner here once they've authorized the
  // client. The redirection will include the authorization code in the
  // query parameters.
  final redirect_url = Uri.parse(
      'nl.tudelft.ide.dcd-mobile-app:/oauth2redirect');
  final basic_url = 'https://dwd.tudelft.nl/api';
  String access_token;
  Thing thing; // holds thing for our client to update

  // creates thing in hub and puts it into client thing member
  Future<Thing> create_thing(String thing_name, String access_token) async
  {
    var addr_url = basic_url + '/things';
    // creating empty thing
    Thing blank = Thing(null, thing_name,null, null, null, null );
    var http_response = await http.post(addr_url,
                                        headers: {'Authorization':
                                                  'Bearer ${access_token}'},
                                        body: blank.to_json());



    if (http_response.statusCode != 200) {
      // If that response was not OK, throw an error.
      throw Exception('Failed to post to thing');
    }

    var json = jsonDecode(http_response.body);
    this.thing = Thing.from_json(json);
    return (this.thing);
  }


}