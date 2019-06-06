// client of DCD,
// used to receive the token and connect to the hub.
class DCDClient
{
  final authorizationEndpoint =
  Uri.parse("https://dwd.tudelft.nl/oauth2/auth");
  final tokenEndpoint =
  Uri.parse("https://dwd.tudelft.nl/oauth2/token");
  final id = "dcd-hub-android";
  final secret = "BZ2y0LDdoGxGqSHBS_0-Dm6wyz";
  // This is a URL on your application's server. The authorization server
  // will redirect the resource owner here once they've authorized the
  // client. The redirection will include the authorization code in the
  // query parameters.
  final redirectUrl = Uri.parse("nl.tudelft.ide.dcd-hub-android:/oauth2redirect");
  String accessToken;

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