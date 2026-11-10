import 'package:flutter/widgets.dart';

/// The app's root navigator.
///
/// Needed because a notification tap arrives outside the widget tree: the
/// plugin callback has no BuildContext, so it pushes through this key. Without
/// it a reminder opened the app but left the user on whatever screen was last
/// visible — the one thing a renewal alert must not do.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
