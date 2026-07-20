import 'package:flutter/material.dart';
import '../widgets/ev_button.dart';
import '../widgets/ev_text_field.dart';
import '../widgets/ev_password_field.dart';

class CreateAccountScreen extends StatelessWidget {
  const CreateAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF102A5E),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

  const SizedBox(height: 10),

  Center(
    child: SizedBox(
      width: 100,
      height: 100,
      child: Image.asset(
        'assets/images/evidence_vault_logo.png',
        fit: BoxFit.contain,
      ),
    ),
  ),

  const SizedBox(height: 10),

  const Center(
    child: Text(
      "Evidence Vault",
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFF102A5E),
      ),
    ),
  ),

  const SizedBox(height: 10),

  const Center(
    child: Text(
      "Helping you preserve your most valuable asset—your truth.",
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 15,
        color: Colors.grey,
        height: 1.6,
      ),
    ),
  ),

  const SizedBox(height: 28),

  Expanded(
    child: Container(
      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(28),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          const Text(
            "Create your secure vault",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF102A5E),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            "Organize your important moments into trusted timelines and professional reports.",
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 28),

          const EVTextField(
          label: "Your Name",
          hint: "John Smith",
          icon: Icons.person_outline,
          ),

          const SizedBox(height: 18),

          const EVTextField(
          label: "Email Address",
          hint: "john@email.com",
          icon: Icons.email_outlined,
          ),
          
          const SizedBox(height: 18),

          const EVPasswordField(
          label: "Password",
          ),

          const SizedBox(height: 18),

          const EVPasswordField(
          label: "Confirm Password",
          ),

          const Spacer(),

          EVButton(
          text: "Create My Vault",
          onPressed: () {},
          ),

                   ),
        ],
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
