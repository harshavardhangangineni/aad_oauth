library aad_oauth;

import 'model/config.dart';
import 'package:flutter/material.dart';
import 'helper/auth_storage.dart';
import 'model/token.dart';
import 'request_code.dart';
import 'request_token.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class AadOAuth {
  static Config _config;
  AuthStorage _authStorage;
  Token _graphToken;
  Token _restToken;
  RequestCode _requestCode;
  RequestToken _requestToken;

  factory AadOAuth(config) {
    if ( AadOAuth._instance == null )
      AadOAuth._instance = new AadOAuth._internal(config);
    return _instance;
  }

  static AadOAuth _instance;

  AadOAuth._internal(config){
    AadOAuth._config = config;
    _authStorage = _authStorage ?? new AuthStorage();
    _requestCode = new RequestCode(_config);
    _requestToken = new RequestToken(_config);
  }

  void setWebViewScreenSize(Rect screenSize) {
    _config.screenSize = screenSize;
  }

  Future<void> login() async {
    await _removeOldTokenOnFirstLogin();
    if (!Token.tokenIsValid(_graphToken) )
      await _performAuthorization();
  }

  Future<String> getAccessToken() async {
    if (!Token.tokenIsValid(_graphToken) )
      await _performAuthorization();

    return _graphToken.accessToken;
  }
    Future<String> getRestApiToken(config) async {
    if (!Token.tokenIsValid(_restToken) )
      await performRestAuth(config);

    return _restToken.accessToken;
  }

  bool tokenIsValid() {
    return Token.tokenIsValid(_graphToken);
  }

  Future<void> logout() async {
    await _authStorage.clear();
    await _requestCode.clearCookies();
    _graphToken = null;
    AadOAuth(_config);
  }

  Future<void> _performAuthorization() async {
    // load token from cache
    _graphToken = await _authStorage.loadTokenToCache();

    //still have refreh token / try to get new access token with refresh token
    if (_graphToken != null)
      await _performRefreshAuthFlow();

    // if we have no refresh token try to perform full request code oauth flow
    else {
      try {
        await _performFullAuthFlow();
      } catch (e) {
        rethrow;
      }
    }

    //save token to cache
    await _authStorage.saveTokenToCache(_graphToken);
  }

  Future<void> _performFullAuthFlow() async {
    String code;
    try {
      code = await _requestCode.requestCode();
      _graphToken = await _requestToken.requestToken(code);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> performRestAuth(restApiConfig) async{
     RequestToken requestToken = new RequestToken(_config);
     if (_graphToken.refreshToken != null) {
      try {
        _restToken = await requestToken.requestRefreshToken(_graphToken.refreshToken);
      } catch (e) {
        //do nothing (because later we try to do a full oauth code flow request)
      }
    }
  }

  Future<void> _performRefreshAuthFlow() async {
    if (_graphToken.refreshToken != null) {
      try {
        _graphToken = await _requestToken.requestRefreshToken(_graphToken.refreshToken);
      } catch (e) {
        //do nothing (because later we try to do a full oauth code flow request)
      }
    }
  }

  Future<void> _removeOldTokenOnFirstLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final _keyFreshInstall = "freshInstall";
    if (!prefs.getKeys().contains(_keyFreshInstall)) {
      logout();
      await prefs.setBool(_keyFreshInstall, false);
    }
  }
}
