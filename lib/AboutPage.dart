import 'package:finance_tracker/GlobalVars.dart';
import 'package:share/share.dart';
import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("About")),
        body: Center(
            child: Container(
                padding: EdgeInsets.all(8),
                child: Column(
                  children: <Widget>[
                    Card(
                        elevation: GlobalVars.listTileElevation,
                        child: ListTile(
                            contentPadding: EdgeInsets.all(16),
                            title: Text("About Me"),
                            subtitle: Text(
                                "Made by [redacted]\nCopyright 2019\nVersion 1.0.0"))),
                    Card(
                        elevation: GlobalVars.listTileElevation,
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          title: Text("Contact"),
                          subtitle: Row(
                            children: [
                              Text("Email: "),
                              InkWell(
                                  onTap: () {
                                    Share.share("[redacted email]",
                                        subject: "Email");
                                  },
                                  child: Text("[redacted email]",
                                      style: TextStyle(
                                          color: Colors.blue,
                                          decoration:
                                              TextDecoration.underline)))
                            ],
                          ),
                        ))
                  ],
                ))));
  }
}
