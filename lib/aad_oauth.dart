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
  static Config _graphConfig;
  static Config _restConfig;
  AuthStorage _authStorage;
  Token _token;
  Token _restToken;
  RequestCode _requestCode;
  RequestToken _requestToken;
  RequestCode _restRequestCode;
  RequestToken _restRequestToken;

  factory AadOAuth(graphConfig,restConfig) {
    if ( AadOAuth._instance == null )
      AadOAuth._instance = new AadOAuth._internal(graphConfig,restConfig);
    return _instance;
  }

  static AadOAuth _instance;

  AadOAuth._internal(graphConfig,restConfig){
    AadOAuth._graphConfig = graphConfig;
    AadOAuth._restConfig = restConfig;
    _authStorage = _authStorage ?? new AuthStorage();
    _requestCode = new RequestCode(_graphConfig);
    _restRequestCode = new RequestCode(_restConfig);
    _requestToken = new RequestToken(_graphConfig);
    _restRequestToken = new RequestToken(_restConfig);
  }

  void setWebViewScreenSize(Rect screenSize) {
    _graphConfig.screenSize = screenSize;
  }

  Future<void> login() async {
    await _removeOldTokenOnFirstLogin();
    if (!Token.tokenIsValid(_token) )
      await _performAuthorization();
  }

  Future<String> getAccessToken() async {
    if (!Token.tokenIsValid(_token) )
      await _performAuthorization();

    return _token.accessToken;
  }

  Future<String> getRestAceessToken(config) async {

    if (!Token.tokenIsValid(_restToken) )
      await _performRefreshAuthFlow();
    
    return _restToken.accessToken;
  }


  bool tokenIsValid() {
    return Token.tokenIsValid(_token);
  }

  Future<void> logout() async {
    await _authStorage.clear();
    await _requestCode.clearCookies();
    await _restRequestCode.clearCookies();
    _token = null;
    AadOAuth(_graphConfig,_restConfig);
  }

  Future<void> _performAuthorization() async {
    // load token from cache
    _token = await _authStorage.loadTokenToCache();

    //still have refreh token / try to get new access token with refresh token
    if (_token != null)
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
    await _authStorage.saveTokenToCache(_token);
  }

  Future<void> _performFullAuthFlow() async {
    String code;
    try {
      code = await _requestCode.requestCode();
      _token = await _requestToken.requestToken(code);
    } catch (e) {
      rethrow;
    }
  }

   Future<void> _performRestAccesTokenFetch() async {
    if (_token.refreshToken != null) {
      try {
        _restToken = await _restRequestToken.requestRefreshToken(_token.refreshToken);
      } catch (e) {
        //do nothing (because later we try to do a full oauth code flow request)
      }
    }
  }

  Future<void> _performRefreshAuthFlow() async {
    if (_token.refreshToken != null) {
      try {
        _token = await _requestToken.requestRefreshToken(_token.refreshToken);
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
