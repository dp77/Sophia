import 'package:flutter/material.dart';

class IntoScreen extends StatefulWidget {
  const IntoScreen({super.key});

  @override
  State<IntoScreen> createState() => _IntoScreenState();
}

class _IntoScreenState extends State<IntoScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Container(height: 430, width: 120, margin: EdgeInsets.only(top: 20), color: Colors.blue),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: SafeArea(
              child: Container(height: 430, width: 120, margin: EdgeInsets.only(top: 100), color: Colors.blue),
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: SafeArea(
              child: Container(height: 430, width: 120, margin: EdgeInsets.only(top: 100), color: Colors.blue),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(height: 500, width: 200, color: Colors.black),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(height: 300, width: double.infinity, color: Colors.yellow),
          ),
        ],
      ),
    );
  }
}
