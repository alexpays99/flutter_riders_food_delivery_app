import 'dart:async';

import 'package:flutter/material.dart';
import 'package:riders_app/authentication/auth_screen.dart';
import 'package:riders_app/global/global.dart';
import 'package:riders_app/mainScreens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  startTimer() {
    Timer(const Duration(seconds: 8), () async {
      //check state if current user auntheticated or not. if yes, navigate user to HomeScreen
      if (firebaseAuth.currentUser != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
        //check state if current user not auntheticated. if yes, navigate user to AuthScreen
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AuthScren(),
          ),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('images/logo.jpg'),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.all(18.0),
                child: Text(
                  'Deliver Food Quickly',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 40,
                    fontFamily: 'Signatra',
                    letterSpacing: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
