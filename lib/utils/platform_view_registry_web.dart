import 'dart:ui_web' as ui_web;

class PlatformViewRegistry {
  static void registerViewFactory(String viewTypeId, dynamic Function(int viewId) viewFactory) {
    ui_web.platformViewRegistry.registerViewFactory(viewTypeId, viewFactory);
  }
}
