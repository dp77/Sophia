import 'package:girlfriend/presentation/widget/sophia_style.dart';
import 'package:girlfriend/core/haptics.dart';
import 'package:flutter/material.dart';
import 'package:girlfriend/presentation/widget/app_background.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: Haptics.wrap(() {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      }),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        color: Colors.transparent,
                        child: const SvgIcon('ic_back', color: Colors.white, size: 18),
                      ),
                    ),
                    const Text(
                      'About Us',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: const SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About AI Girlfriend',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'AI Girlfriend is a virtual companion app designed to provide you with a friendly and engaging chat experience. Our goal is to create a safe and private space where you can interact with an AI-powered girlfriend without any worries about your personal information.',
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Our Commitment to Privacy',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'We are committed to protecting your privacy. We do not require any authentication, and all your chat data is stored locally on your device. We do not store any of your conversations on our servers, ensuring that your interactions remain completely private.',
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Contact Us',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'We welcome your feedback and are here to help with any issues you may encounter. If you have any questions, suggestions, or need to report a problem, please feel free to contact us at embeepay141@gmail.com.',
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Last Updated: February 2, 2026',
                        style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.white),
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
