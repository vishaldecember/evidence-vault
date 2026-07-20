import 'package:flutter/material.dart';
import 'create_account_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Column(
            children: [

              const SizedBox(height: 20),

              Center(
                  child: SizedBox(
                  width: 190,
                  height: 150,
                  child: Image.asset(
                         'assets/images/evidence_vault_logo.png',
                          fit: BoxFit.contain,
                        ),
                ),
               ),
                        
              const SizedBox(height: 2),

const Text(
  "Have you ever wished you had\nproof of what really happened?",
  textAlign: TextAlign.center,
  style: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Color(0xFF102A5E),
    height: 1.3,
  ),
),

const SizedBox(height: 16),

const Text(
  "Helping you preserve your most valuable asset—\nyour truth.",

  textAlign: TextAlign.center,
  style: TextStyle(
    fontSize: 15,
    color: Color(0xFF6B7280),
    height: 1.5,
  ),
),

const SizedBox(height: 18),

Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 8,
  ),
  decoration: BoxDecoration(
    color: Color(0xFFF4F7FF),
    borderRadius: BorderRadius.all(
      Radius.circular(14),
    ),
  ),
  child: const Text(
    "Evidence Vault automatically transforms life's moments into trusted timelines \n and professional reports—helping you organize, understand, and confidently stand with you.",
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Color(0xFF102A5E),
      height: 1.4,
    ),
  ),
),

const SizedBox(height: 12),

             

              

              

              

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [

                  Expanded(
                    child: FeatureCard(
                      icon: Icons.lock,
                      title: "Encrypted",
                      subtitle: "End-to-End Protection",
                    ),
                  ),

                  SizedBox(width: 10),

                  Expanded(
                    child: FeatureCard(
                      icon: Icons.access_time,
                      title: "Time Stamped",
                      subtitle: "Trusted Date & Time",
                    ),
                  ),

                  SizedBox(width: 10),

                  Expanded(
                    child: FeatureCard(
                      icon: Icons.folder_copy,
                      title: "Organised",
                      subtitle: "All your records",
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                builder: (_) => const CreateAccountScreen(),
                  ),
                 );
                },
                  style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B36F4),
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: const Color(0x553B36F4),
                  shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                    ),
                   ),
                  child: const Text(
                    "Create Account",
                    style: TextStyle(fontSize: 17),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: const [

                  Expanded(child: Divider()),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text("OR"),
                  ),

                  Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 12),

              SocialButton(
              icon: "assets/icons/google.png",
              text: "Continue with Google",
              onTap: () {},
              ),
                 
              const SizedBox(height: 14),

              SocialButton(
              icon: "assets/icons/apple.png",
              text: "Continue with Apple",
              onTap: () {},
              ),
              
                            
              

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  const Text(
                    "Already have an account?",
                  ),

                  TextButton(
                    onPressed: () {},
                    child: const Text("Log in"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

        Icon(
          icon,
          color: const Color(0xFF3B36F4),
        ),

        const SizedBox(height: 8),

        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 4),

        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class SocialButton extends StatelessWidget {
  final String icon;
  final String text;
  final VoidCallback onTap;

  const SocialButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Image.asset(
            icon,
            width: 22,
            height: 22,
          ),
          label: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: BorderSide(
              color: Color(0xFFE5E7EB),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}