import 'meal_route.dart';
import 'dart:convert';

/// FCM data values are strings; older senders may JSON-encode parameters.
/// Only route to screens that can load their own persisted data.
String notificationRoute(Map<String, dynamic> data) {
  final parameters = <String, dynamic>{};
  final raw = data['parameters'] ?? data['navigationParameters'];
  if (raw is Map<String, dynamic>) {
    parameters.addAll(raw);
  } else if (raw is String) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) parameters.addAll(decoded);
    } on FormatException {
      // A malformed notification should still open a usable screen.
    }
  }
  parameters.addAll(data);
  final type = parameters['type'];
  final mealEvent = const {
    'mealAccepted',
    'mealCompleted',
    'mealNotCompleted',
    'mealReplaced'
  }.contains(type);
  final mealId =
      parameters['mealId'] ?? (mealEvent ? parameters['targetId'] : null);
  final planId = parameters['planId'] ?? parameters['relatedPlanId'];
  final path = parameters['planPath'];
  final validPath = path is String &&
      RegExp(r'^(users|families)/[^/]+/mealPlans/[^/]+$').hasMatch(path);
  final validPlanId =
      planId is String && planId.isNotEmpty && !planId.contains('/');
  if (validPath || validPlanId) {
    return Uri(path: '/notification-target', queryParameters: {
      if (validPath) 'plan': path,
      if (validPlanId) 'planId': planId,
      if (mealId is String && mealId.isNotEmpty && !mealId.contains('/'))
        'mealId': mealId,
    }).toString();
  }
  if (mealId is String && mealId.isNotEmpty && !mealId.contains('/')) {
    return mealRoute(mealId, null);
  }
  if (parameters['planId'] != null || data['route'] == '/generated-plan') {
    return '/saved-meal-plans';
  }
  const routes = {
    '/home',
    '/meal-plan',
    '/saved-meal-plans',
    '/meal-history',
    '/pantry',
    '/grocery',
    '/profile',
    '/family-space',
    '/household-dashboard',
    '/ai-settings',
    '/notifications',
  };
  final route = parameters['route'] ?? parameters['navigationRoute'];
  if (route is String && routes.contains(route)) return route;
  if (type is String) {
    if (type.startsWith('pantry')) return '/pantry';
    if (type.startsWith('grocery')) return '/grocery';
    if (type.startsWith('aiProvider')) return '/ai-settings';
    if (type.startsWith('mealPlan')) return '/saved-meal-plans';
    if (type.startsWith('meal')) return '/meal-plan';
    if (type.startsWith('member') || type == 'familyUpdate') {
      return '/family-space';
    }
  }
  return '/home';
}
