import 'package:flutter/material.dart';
import 'workspace_intro_screen.dart';

class WorkspaceOnboardingScreen extends StatefulWidget {
  final String userId;
  final String token;

  const WorkspaceOnboardingScreen({
    Key? key,
    required this.userId,
    required this.token,
  }) : super(key: key);

  @override
  State<WorkspaceOnboardingScreen> createState() => _WorkspaceOnboardingScreenState();
}

class _WorkspaceOnboardingScreenState extends State<WorkspaceOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      icon: Icons.people,
      title: 'Team Management',
      description: 'Easily add team members and assign roles like Owner, Manager, or Member. Control who can submit expenses and who can approve them.',
    ),
    OnboardingStep(
      icon: Icons.bar_chart,
      title: 'Expense Workflow',
      description: 'Employees submit expenses, managers review and approve, and finance tracks everything in one place with automated workflows.',
    ),
    OnboardingStep(
      icon: Icons.show_chart,
      title: 'Analytics & Reporting',
      description: 'Get detailed reports on team spending, category breakdowns, and approval status across your organization with visual dashboards.',
    ),
    OnboardingStep(
      icon: Icons.vpn_key,
      title: 'License Management',
      description: 'Each team member needs a license. Start with one and upgrade as your team grows with our affordable, flexible plans.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF7E5EFD),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 20),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'MR',
                          style: TextStyle(
                            color: Color(0xFF7E5EFD),
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'TeamHub',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Content area
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemCount: _steps.length,
                          itemBuilder: (context, index) {
                            return _buildOnboardingPage(_steps[index]);
                          },
                        ),
                      ),
                      // Pagination dots
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _steps.length,
                            (index) => _buildDot(index == _currentPage),
                          ),
                        ),
                      ),
                      // Navigation buttons
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            if (_currentPage > 0)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    _pageController.previousPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black87,
                                    side: const BorderSide(color: Colors.grey, width: 1),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Back',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            if (_currentPage > 0) const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  if (_currentPage < _steps.length - 1) {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  } else {
                                    // Navigate to intro screen after onboarding
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => WorkspaceIntroScreen(
                                          userId: widget.userId,
                                          token: widget.token,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7E5EFD),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _currentPage < _steps.length - 1 ? 'Next' : 'Get Started',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            if (_currentPage == 0) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    // Skip onboarding and go directly to intro screen
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => WorkspaceIntroScreen(
                                          userId: widget.userId,
                                          token: widget.token,
                                        ),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black87,
                                    side: const BorderSide(color: Colors.grey, width: 1),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Skip',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
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

  Widget _buildOnboardingPage(OnboardingStep step) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              step.icon,
              size: 100,
              color: const Color(0xFF7E5EFD),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            step.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              step.description,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                height: 1.5,
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 12 : 8,
      height: isActive ? 12 : 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF7E5EFD) : Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
    );
  }
}

class OnboardingStep {
  final IconData icon;
  final String title;
  final String description;

  OnboardingStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}

