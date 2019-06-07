// client of DCD,
// used to receive the token and connect to the hub.
class DCD_client
{
  final authorization_endpoint =
  Uri.parse("https://dwd.tudelft.nl/oauth2/auth");
  final token_endpoint =
  Uri.parse("https://dwd.tudelft.nl/oauth2/token");
  final id = "dcd-hub-android";
  final secret = "BZ2y0LDdoGxGqSHBS_0-Dm6wyz";
  // This is a URL on your application's server. The authorization server
  // will redirect the resource owner here once they've authorized the
  // client. The redirection will include the authorization code in the
  // query parameters.
  final redirect_url = Uri.parse("nl.tudelft.ide.dcd-hub-android:/oauth2redirect");
  String access_token;
  Map<String, dynamic> object_map;
}

class DCD_broker
{
  bool find_or_create_thing()
  {
    return(true);
  }

  bool find_or_create_property()
  {
    return(true);
  }

  bool upload_values()
  {

  }


}