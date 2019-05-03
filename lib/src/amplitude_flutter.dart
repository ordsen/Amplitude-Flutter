import 'dart:async';

import 'package:flutter/foundation.dart';

import 'config.dart';
import 'device_info.dart';
import 'event.dart';
import 'event_buffer.dart';
import 'identify.dart';
import 'location.dart';
import 'revenue.dart';
import 'service_provider.dart';
import 'session.dart';

class AmplitudeFlutter {
  AmplitudeFlutter(String apiKey, [this.config]) {
    config ??= Config();
    provider = ServiceProvider(apiKey: apiKey, timeout: config.sessionTimeout);
    _init();
  }

  @visibleForTesting
  AmplitudeFlutter.private(this.provider, this.config) {
    _init();
  }

  Config config;
  DeviceInfo deviceInfo;
  EventBuffer buffer;
  Location location;
  ServiceProvider provider;
  Session session;
  dynamic userId;

  /// Set the user id associated with events
  void setUserId(dynamic userId) {
    this.userId = userId;
  }

  /// Log an event
  Future<void> logEvent(
      {@required String name,
      Map<String, dynamic> properties = const <String, String>{}}) async {
    session.refresh();

    if (config.optOut) {
      return Future.value(null);
    }

    final Event event =
        Event(name, sessionId: session.getSessionId(), props: properties)
          ..addProps(deviceInfo.get());

    if (userId != null) {
      event.addProp('user_id', userId);
    }

    if (location != null) {
      final locInfo = await location.getLocation();
      event.addProps(<String, dynamic>{'api_properties': locInfo});
    }

    return buffer.add(event);
  }

  /// Identify the current user
  Future<void> identify(Identify identify,
      {Map<String, dynamic> properties = const <String, dynamic>{}}) async {
    return logEvent(
        name: r'$identify',
        properties: <String, dynamic>{'user_properties': identify.payload}
          ..addAll(properties));
  }

  /// Adds the current user to a group
  Future<void> setGroup(String groupType, dynamic groupValue) async {
    return identify(Identify()..set(groupType, groupValue),
        properties: <String, dynamic>{
          'groups': <String, dynamic>{groupType: groupValue}
        });
  }

  /// Sets properties on a group
  Future<void> groupIdentify(
      String groupType, dynamic groupValue, Identify identify) async {
    return logEvent(name: r'$groupidentify', properties: <String, dynamic>{
      'group_properties': identify.payload,
      'groups': <String, dynamic>{groupType: groupValue}
    });
  }

  /// Log a revenue event
  Future<void> logRevenue(Revenue revenue) async {
    if (revenue.isValid()) {
      return logEvent(
          name: Revenue.EVENT,
          properties: <String, dynamic>{'event_properties': revenue.payload});
    }
  }

  /// Manually flush events in the buffer
  Future<void> flushEvents() => buffer.flush();

  void _init() {
    deviceInfo = provider.deviceInfo;
    session = provider.session;
    buffer = EventBuffer(provider, config);

    location = config.useLocation ? provider.getLocation() : null;

    session.start();
  }
}
