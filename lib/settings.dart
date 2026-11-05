import 'package:flutter/material.dart';

class ColorSetting {
  static final Map<String, Color> colors = {
    'blue': Color(0xFF4FC3F7),
    'red': Color(0xFFEF5350),
    'green': Color(0xFF66BB6A),
    'purple': Color(0xFFEA80FC),
    'pink': Color(0xFFFF80AB),
    'black': Colors.black,
    'orange': Color(0xFFFFD180),
    'black54': Colors.black54
  };

  final Color _navbarColor;

  final Color _textColor;

  ColorSetting(this._navbarColor, this._textColor);

  static ColorSetting config(
  {
    String navbar = 'blue',
    String text = 'black54'
  }
  ) {
      return ColorSetting(colors[navbar]!, colors[text]!);
  }

  Color get navbarColor => _navbarColor;
  Color get textColor => _textColor;



}




