import 'package:flutter/material.dart';



import '../screens/create_account_screen.dart';

import '../screens/forgot_password_screen.dart';

import '../screens/login_screen.dart';

import '../theme/app_motion.dart';



/// Shared auth navigation with calm Material-style transitions.

abstract final class AuthNavigation {

  static Route<T> route<T>(Widget page, {String? name}) {

    return PageRouteBuilder<T>(

      settings: RouteSettings(name: name),

      transitionDuration: AppMotion.page,

      reverseTransitionDuration: AppMotion.page,

      pageBuilder: (context, animation, secondaryAnimation) => page,

      transitionsBuilder: (context, animation, secondaryAnimation, child) {

        return buildPageTransition(animation, secondaryAnimation, child);

      },

    );

  }



  static Future<T?> push<T>(BuildContext context, Widget page) {

    return Navigator.push<T>(context, route(page));

  }



  static Future<T?> replace<T>(BuildContext context, Widget page) {

    return Navigator.pushReplacement<T, void>(context, route(page));

  }



  static void openLogin(BuildContext context) {

    replace(context, const LoginScreen());

  }



  static void openCreateAccount(BuildContext context) {

    replace(context, const CreateAccountScreen());

  }



  static Future<void> openForgotPassword(BuildContext context) {

    return push(context, const ForgotPasswordScreen());

  }

}


