library aad_oauth;

import 'dart:io';

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
  static Config _graphConsentsConfig;
  static Config _restConfig;
  AuthStorage _authStorage;
  Token _token;
  Token _restToken;
  RequestCode _requestCode;
  RequestToken _requestToken;
  RequestCode _restRequestCode;
  RequestToken _graphRequestToken;
  RequestToken _restRequestToken;

  factory AadOAuth(graphConfig, restConfig, graphConsentsConfig) {
    if (AadOAuth._instance == null)
      AadOAuth._instance =
          new AadOAuth._internal(graphConfig, restConfig, graphConsentsConfig);
    return _instance;
  }

  static AadOAuth _instance;

  AadOAuth._internal(graphConfig, restConfig, graphConsentsConfig) {
    AadOAuth._graphConfig = graphConfig;
    AadOAuth._restConfig = restConfig;
    AadOAuth._graphConsentsConfig = graphConsentsConfig;
    _authStorage = _authStorage ?? new AuthStorage();
    _requestCode = new RequestCode(_graphConfig);
    _restRequestCode = new RequestCode(_restConfig);
    _requestToken = new RequestToken(_graphConfig);
    _restRequestToken = new RequestToken(_restConfig);
    _graphRequestToken = new RequestToken(_graphConsentsConfig);
  }

  void setWebViewScreenSize(Rect screenSize) {
    _graphConfig.screenSize = screenSize;
  }

  Future<void> login() async {
    await _removeOldTokenOnFirstLogin();
    await _checkFreshInstall();
    if (!Token.tokenIsValid(_token)) await _performAuthorization();
  }

  Future<String> getAccessToken() async {
    if (!Token.tokenIsValid(_token)) await _performAuthorization();

    return _token.accessToken;
  }

  Future<String> getRestAceessToken() async {
    if (!Token.tokenIsValid(_restToken)) await _performRestAccesTokenFetch();

    return _restToken.accessToken;
  }

  Future<String> getGraphAccessTokenWithConsents() async {
    if (!Token.tokenIsValid(_restToken))
      await _performAdminConsentGraphAccessTokenFetch();

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
    AadOAuth(_graphConfig, _restConfig, _graphConsentsConfig);
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
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final _keyFreshInstall = "isFreshInstall";
      var isFreshInstall = prefs.getBool(_keyFreshInstall) ?? true;
      if (Platform.isIOS && isFreshInstall) {
        // Remove the code if the fresh installl issue is removed
        final result = await Future.any([
          _requestCode.requestCode(),
          Future.delayed(const Duration(seconds: 8))
        ]);
      }
      code = await _requestCode.requestCode();
      _token = await _requestToken.requestToken(code);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _performRestAccesTokenFetch() async {
    if (_token.refreshToken != null) {
      try {
        _restToken =
            await _restRequestToken.requestRefreshToken(_token.refreshToken);
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

  Future<void> _performAdminConsentGraphAccessTokenFetch() async {
    if (_token.refreshToken != null) {
      try {
        _token =
            await _graphRequestToken.requestRefreshToken(_token.refreshToken);
        await _performRestAccesTokenFetch();
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

  Future<void> _checkFreshInstall() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final _keyFreshInstall = "isFreshInstall";
    if (prefs.getKeys().contains(_keyFreshInstall)) {
      await prefs.setBool(_keyFreshInstall, false);
    } else {
      await prefs.setBool(_keyFreshInstall, true);
    }
  }
}
