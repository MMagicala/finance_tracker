import 'package:flutter/material.dart';

class TitleItem extends StatelessWidget{
  String text;
  TitleItem(this.text);
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(child:Text(text,
        style: TextStyle(fontSize: 18)), padding: EdgeInsets.all(8), alignment: Alignment.center,);
  }
}