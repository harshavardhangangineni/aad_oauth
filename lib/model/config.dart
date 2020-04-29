import 'package:flutter/widgets.dart';

class Config {
  final String azureTenantId;
  String azureTenantName;
  String authorizationUrl;
  String tokenUrl;
  final String clientId;
  final String clientSecret;
  final String redirectUri;
  final String responseType;
  final String contentType;
  final String scope;
  final String resource;

  Rect screenSize;
  String tokenIdentifier;

  Config(this.azureTenantId, this.clientId, this.scope, this.redirectUri,
      {this.clientSecret,
      this.resource,
      this.azureTenantName,
      this.responseType = "code",
      this.contentType = "application/x-www-form-urlencoded",
      this.tokenIdentifier = "Token",
      this.screenSize}) {
    this.authorizationUrl =
        "https://login.microsoftonline.com/$azureTenantId/oauth2/authorize";
    this.tokenUrl =
        "https://login.microsoftonline.com/$azureTenantId/oauth2/token";
  }
}
