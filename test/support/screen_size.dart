import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// A phone-sized screen, narrow enough for the search to open in a sheet.
const phoneScreen = Size(400, 800);

/// A desktop-sized screen, wide enough for the search to sit beside the team.
const desktopScreen = Size(1200, 800);

/// Makes the test screen [size] (one logical pixel per physical pixel) for the
/// rest of the test.
void useScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
