// Flutter side of Hub structures


class Thing
{
  String id;
  String name;
  String description;
  String type;
  List<dynamic> properties;
  int readAt;
  Map<String, dynamic> keys;

  Thing(this.id,
        this.name,
        this.description,
        this.type,
        this.properties,
        this.readAt,
        this.keys);

  // named constructor from json object
  // also using an initializer list
  Thing.from_json(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        description = json['description'],
        type = json['type'],
        properties = json['properties'],
        readAt = json['readAt'],
        keys =  json['keys'];

  // arrow notation (replaces {return x;}
  Map<String, dynamic> to_json() =>
      {
        'id': id,
        'name': name,
        'description': description,
        'type': type,
        'properties': properties,
        'readAt': readAt,
        'keys': keys,
      };

}

// supported types so far : ACCELEROMETER, GYROSCOPE
class Property
{
  String id;
  String name;
  String description;
  String type;

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
        type = json['type'];

  // arrow notation (replaces {return x;}
  Map<String, dynamic> to_json() =>
      {
        'id': id,
        'name': name,
        'description': description,
        'type': type,
      };
}



List<dynamic> Properties;
// client of DCD,
// used to receive the token and connect to the hub.
class DCD_client extends DCD_broker
{
  final authorization_endpoint =
  Uri.parse('https://dwd.tudelft.nl/oauth2/auth');
  final token_endpoint =
  Uri.parse('https://dwd.tudelft.nl/oauth2/token');
  final id = 'dcd-hub-android';
  final secret = 'BZ2y0LDdoGxGqSHBS_0-Dm6wyz';
  // This is a URL on your application's server. The authorization server
  // will redirect the resource owner here once they've authorized the
  // client. The redirection will include the authorization code in the
  // query parameters.
  final redirect_url = Uri.parse('nl.tudelft.ide.dcd-hub-android:/oauth2redirect');
  String access_token;
  Map<String, dynamic> object_map; // holds things list

}

class DCD_broker
{
  // Finds or creates thing in hub, return false if error
  bool find_or_create_thing()
  {

    return(true);
  }

  // Finds or creates property in hub, return false if error
  bool find_or_create_property()
  {

    return(true);
  }

  // Finds or creates property in hub, return false if error
  bool upload_values()
  {

    return(true);
  }


}

