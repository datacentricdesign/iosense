// Flutter side of Hub structures
import 'dart:convert';
import 'package:http/http.dart' as http;

class Thing
{
  String id;
  String name;
  String description;
  String type;
  List<Object> properties;
  int readAt;
  String token;
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
        // taking a json input, for each object in properties
        // will place a Property into the list,  created with said object
        properties = [ for (var property_json in json['properties']) Property.from_json(property_json)],
        readAt = json['readAt'],
        token =   json['keys']['jwt'];





  // arrow notation =>x (replaces  with {return x}
  Map<String, dynamic> to_json() =>
      {

          if(id!= null) 'id':id,
          if(name!=null)'name': name,
          if(description!=null)'description': description,
          if(type!=null)'type': type,
          if(properties!=null)'properties': properties,
          if(readAt!=null)'readAt': readAt,
      };


  // Given an EXISTING thing, and an access token,
  // creates a property in it of type prop_type,
  // and returns created property
  Future<Property> create_property(String prop_type, String access_token) async
  {
    if( this.id == null) throw Exception("Invalid thing id");
    // basic address
    var addr_url = 'https://dwd.tudelft.nl/api/things/${this.id}/properties';

    Property blank = Property(null, prop_type.toLowerCase(), null, prop_type);
    //blank property,except type and name
    // if it is location data
    if(prop_type == "FOUR_DIMENSIONS")
    {
          blank.name = "4D location";
          blank.description =
                                 """saves 4D location data:
                                 latitude in degrees normalized to the interval [-90.0,+90.0]
                                 longitude in degrees normalized to the interval [-90.0,+90.0]
                                 altitude in meters
                                 speed at which the device is traveling in m/s over ground
                                 """;
    }


    var http_response = await http.post(addr_url,
                                        headers: {'Authorization':
                                                  'Bearer ${access_token}',
                                                  'Content-Type' :
                                                  'application/json',
                                                  'Response-Type':
                                                  'application/json'},
                                        body: jsonEncode( blank.to_json()));

    if (http_response.statusCode != 201)
    {
      // If that response was not OK, throw an error.
      throw Exception('Failed to post property to thing');
    }

    var json = jsonDecode(http_response.body);
    // adding a new property to our thing
    this.properties.add(Property.from_json(json['property'])
    );

    return(Property.from_json(json));
  }

  // updates property values given property, values and access token
  Future<void>update_property(Property property , List<dynamic> values, String access_token) async
  {
    var addr_url = 'https://dwd.tudelft.nl/api/things/${this.id}/properties/${property.id}';


    // struct of data to send to server value :[[ tmstamp, ... ]]
    var temp = <Object>[];
    // if four dimensions, timestamp is given by last value
    temp.add((property.type == "FOUR_DIMENSIONS") ? (values[4].millisecondsSinceEpoch) : DateTime.now().millisecondsSinceEpoch);
    temp += (property.type != "FOUR_DIMENSIONS")? values : values.sublist(0, 4);
    property.values =  temp; // setting the values of the property that's replaced



    //var lala = (jsonEncode(property.to_json()));
    // printing post message
    //debugPrint(jsonEncode(property.to_json());
    var http_response = await http.put(addr_url,
                                        headers: {'Authorization':
                                                  'Bearer ${access_token}',
                                                  'Content-Type' :
                                                  'application/json',
                                                  'Response-Type':
                                                  'application/json'},
                                        body: jsonEncode(property.to_json()));

    if (http_response.statusCode != 200)
    {
      // If that response was not OK, throw an error.
      throw Exception('''Failed to post property values 
                      ${property.values} 
                      to property with id ${property.id}, 
                      from thing with id: ${this.id} 
                      to the following link:
                      ${addr_url}''');
    }

    //var json =  await jsonDecode(http_response.body);
    //return(Property.from_json(json));
  }

}


// supported types so far : ACCELEROMETER, GYROSCOPE, 5_DIMENSIONS
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

  // overriding function for jsonEncode Call
  Map<String, dynamic> toJson() => to_json();

  // arrow notation (replaces {return x;}
  Map<String, dynamic> to_json() =>
      {
        // only create fields of json is value is not null
        if(id!= null) 'id':id,
        if(name!=null)'name': name,
        if(description!=null)'description': description,
        if(type!=null)'type': type,
        if(values!=null)'values': [values],
      };

}

// client of DCD,
// used to receive token, connect and interact with the hub.
class DCD_client {
  final authorization_endpoint =
  Uri.parse('https://dwd.tudelft.nl/oauth2/auth');
  final token_endpoint =
  Uri.parse('https://dwd.tudelft.nl/oauth2/token');
  final id = 'clients:dcd-app-mobile';

  // This is a URL on your application's server. The authorization server
  // will redirect the resource owner here once they've authorized the
  // client. The redirection will include the authorization code in the
  // query parameters.
  final redirect_url = Uri.parse(
      'nl.tudelft.ide.dcd-app-mobile:/oauth2redirect');
  final basic_url = 'https://dwd.tudelft.nl/api';

  String access_token; // holds access token for our hub connection
  Thing thing ; // holds thing for our client to update

  // default constructor
  DCD_client();

  // creates thing in hub and puts it into client thing member
  Future<Thing> create_thing(String thing_name, String access_token) async
  {
    var addr_url = basic_url + '/things?jwt=true';
    // creating empty thing
    Thing blank = Thing(null,thing_name,null, "test", null, null );
    var http_response = await http.post(addr_url,
                                        headers: {'Authorization':
                                                  'Bearer ${access_token}',
                                                  'Content-Type' :
                                                  'application/json',
                                                  'Response-Type':
                                                  'application/json'},
                                        body: jsonEncode(blank.to_json()),

                                        );



    if (http_response.statusCode != 201) {
      // If that response was not OK, throw an error.
      throw Exception('Failed to post to thing');
    }

    var json = jsonDecode(http_response.body);
    this.thing = Thing.from_json(json['thing']);
    return (this.thing);
  }

  // structure for  deleting all things in hub
  void delete_things_hub( List<String> ids_to_delete)
  {

    ids_to_delete.forEach((prop_id_to_delete) async{
      var http_response = await http.delete('https://dwd.tudelft.nl/api/things/${prop_id_to_delete}',
          headers: {'Authorization': 'Bearer ${this.access_token}'});

    });

  }

}