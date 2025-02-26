import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_places_web/src/search_results_tile.dart';
import 'package:rainbow_color/rainbow_color.dart';
import 'package:uuid/uuid.dart';

class FlutterGooglePlacesWeb extends StatefulWidget {
  ///[value] stores the clicked address data in
  ///FlutterGooglePlacesWeb.value['name'] = '1600 Amphitheatre Parkway, Mountain View, CA, USA';
  ///FlutterGooglePlacesWeb.value['streetAddress'] = '1600 Amphitheatre Parkway';
  ///FlutterGooglePlacesWeb.value['city'] = 'CA';
  ///FlutterGooglePlacesWeb.value['country'] = 'USA';
  static late Map<String, String> value;

  ///[showResults] boolean shows results container
  static bool showResults = false;

  ///This is the API Key that is needed to communicate with google places API
  ///Get API Key: https://developers.google.com/places/web-service/get-api-key
  final String apiKey;

  ///Proxy to be used if having CORS XMLError or want to use for security
  final String? proxyURL;

  ///The position, in the input term, of the last character that the service uses to match predictions.
  ///For example, if the input is 'Google' and the [offset] is 3, the service will match on 'Goo'.
  ///The string determined by the [offset] is matched against the first word in the input term only.
  ///For example, if the input term is 'Google abc' and the [offset] is 3, the service will attempt to match against 'Goo abc'.
  ///If no [offset] is supplied, the service will use the whole term. The [offset] should generally be set to the position of the text caret.
  final int? offset;

  ///[sessionToken] is a boolean that enable/disables a UUID v4 session token. [sessionToken] is [true] by default.
  ///Google recommends using session tokens for all autocomplete sessions
  ///Read more about session tokens https://developers.google.com/places/web-service/session-tokens
  final bool sessionToken;

  ///Currently, you can use components to filter by up to 5 countries.
  ///Countries must be passed as a two character, ISO 3166-1 Alpha-2 compatible country code.
  ///For example: components=country:fr would restrict your results to places within France.
  ///Multiple countries must be passed as multiple country:XX filters, with the pipe character (|) as a separator.
  ///For example: components=country:us|country:pr|country:vi|country:gu|country:mp would restrict your results to places within the United States and its unincorporated organized territories.
  final String? components;
  final InputDecoration? decoration;
  final bool required;

  final void Function(String address)? onAddressSelected;

  FlutterGooglePlacesWeb({
    Key? key,
    required this.apiKey,
    this.proxyURL,
    this.offset,
    this.components,
    this.sessionToken = true,
    this.decoration,
    required this.required,
    this.onAddressSelected,
  });

  @override
  FlutterGooglePlacesWebState createState() => FlutterGooglePlacesWebState();
}

class FlutterGooglePlacesWebState extends State<FlutterGooglePlacesWeb>
    with SingleTickerProviderStateMixin {
  final controller = TextEditingController();
  late AnimationController _animationController;
  late Animation<Color> _loadingTween;
  List<Address> displayedResults = [];
  String? _sessionToken;
  var uuid = Uuid();

  Future<List<Address>> getLocationResults(String inputText) async {
    if (_sessionToken == null && widget.sessionToken == true) {
      setState(() {
        _sessionToken = uuid.v4();
      });
    }

    if (inputText.isEmpty) {
      setState(() {
        FlutterGooglePlacesWeb.showResults = false;
      });
    } else {
      setState(() {
        FlutterGooglePlacesWeb.showResults = true;
      });
    }

    String type = 'address';
    Uri actualUrl = Uri(
      scheme: 'https',
      host: 'maps.googleapis.com',
      path: '/maps/api/place/autocomplete/json',
      queryParameters: {
        'input': inputText,
        'types': type,
        'key': widget.apiKey,
        'sessiontoken': _sessionToken,
        if (widget.offset != null) 'offset': widget.offset,
        if (widget.components != null) 'components': widget.components,
      },
    );
    String proxiedUrl;
    if (widget.proxyURL == null) {
      proxiedUrl = actualUrl.toString();
    } else {
      final offsetUri = Uri.parse(widget.proxyURL!);
      proxiedUrl = Uri(
        scheme: offsetUri.scheme,
        host: offsetUri.host,
        port: offsetUri.port,
        path: offsetUri.path,
        queryParameters: {
          'u': actualUrl.toString(),
        },
      ).toString();
    }

    //print(actualUrl.toString());
    //print(proxiedUrl);
    Response response = await Dio().get(proxiedUrl);
    var predictions = response.data['predictions'];
    if (predictions != []) {
      displayedResults.clear();
    }

    for (var i = 0; i < predictions.length; i++) {
      String name = predictions[i]['description'];
      String streetAddress =
          predictions[i]['structured_formatting']['main_text'];
      List<dynamic> terms = predictions[i]['terms'];
      String city = terms[terms.length - 2]['value'];
      String country = terms[terms.length - 1]['value'];
      displayedResults.add(Address(
        name: name,
        streetAddress: streetAddress,
        city: city,
        country: country,
      ));
    }

    return displayedResults;
  }

  selectResult(Address clickedAddress) {
    setState(() {
      FlutterGooglePlacesWeb.showResults = false;
      controller.text = clickedAddress.name;
      FlutterGooglePlacesWeb.value['name'] = clickedAddress.name;
      FlutterGooglePlacesWeb.value['streetAddress'] =
          clickedAddress.streetAddress;
      FlutterGooglePlacesWeb.value['city'] = clickedAddress.city;
      FlutterGooglePlacesWeb.value['country'] = clickedAddress.country;
    });

    final onAddressSelected = widget.onAddressSelected;
    if (onAddressSelected != null) {
      onAddressSelected(clickedAddress.name);
    }
  }

  @override
  void initState() {
    FlutterGooglePlacesWeb.value = {};
    _animationController =
        AnimationController(duration: Duration(seconds: 3), vsync: this);
    _loadingTween = RainbowColorTween([
      //Google Colors
      Color(0xFF4285F4), //Google Blue
      Color(0xFF0F9D58), //Google Green
      Color(0xFFF4B400), //Google Yellow
      Color(0xFFDB4437), //Google Red
    ]).animate(_animationController)
      ..addListener(() {
        setState(() {});
      });
    _animationController.forward();
    _animationController.repeat();
    super.initState();
  }

  final addressFormKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: Axis.vertical,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Container(
            alignment: Alignment.center,
            child: Stack(
              children: [
                //search field
                TextFormField(
                  key: widget.key,
                  controller: controller,
                  decoration: widget.decoration,
                  validator: (value) {
                    if (widget.required == true && value!.isEmpty) {
                      return 'Please enter an address';
                    }
                    return null;
                  },
                  onChanged: (text) {
                    setState(() {
                      getLocationResults(text);
                    });
                  },
                ),
                FlutterGooglePlacesWeb.showResults
                    ? Padding(
                        padding: EdgeInsets.only(top: 50),
                        child: Container(
                          width: MediaQuery.of(context).size.width,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                fit: FlexFit.loose,
                                child: displayedResults.isEmpty
                                    ? Container(
                                        padding: EdgeInsets.only(
                                            top: 102, bottom: 102),
                                        child: CircularProgressIndicator(
                                          valueColor: _loadingTween,
                                          strokeWidth: 6.0,
                                        ),
                                      )
                                    : ListView(
                                        shrinkWrap: true,
                                        children: displayedResults
                                            .map((Address addressData) =>
                                                SearchResultsTile(
                                                    addressData: addressData,
                                                    callback: selectResult,
                                                    address:
                                                        FlutterGooglePlacesWeb
                                                            .value))
                                            .toList(),
                                      ),
                              ),
                              Container(
                                height: 30,
                                child: Image.asset(
                                  'packages/flutter_google_places_web/assets/google_white.png',
                                  scale: 3,
                                ),
                              ),
                            ],
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                                color: Colors.grey[200]!, width: 0.5),
                          ),
                        ),
                      )
                    : Container(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    controller.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

class Address {
  String name;
  String streetAddress;
  String city;
  String country;
  Address({
    required this.name,
    required this.streetAddress,
    required this.city,
    required this.country,
  });
}
