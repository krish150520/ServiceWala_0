import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_wala_business/config/constants.dart';
import 'package:service_wala_business/config/theme.dart';
import 'package:service_wala_business/providers/app_state.dart';
import 'package:service_wala_business/screens/home/main_shell.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1: Personal details
  final _nameController = TextEditingController();

  // Step 2: Services
  final Set<String> _selectedServices = {'electrician', 'ac_repair'};

  // Step 3: Location
  String _serviceArea = 'Amritsar, Punjab';
  bool _locationPermissionGranted = false;

  // Optional
  final _experienceController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final agent = context.read<AppState>().agent;
    if (agent != null) {
      if (agent.fullName.isNotEmpty && agent.fullName != 'Partner') {
        _nameController.text = agent.fullName;
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _experienceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        _showError('Please enter your full name');
        return;
      }
    } else if (_currentStep == 1) {
      if (_selectedServices.isEmpty) {
        _showError('Please select at least one service category');
        return;
      }
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeSetup();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _completeSetup() async {
    final appState = context.read<AppState>();
    final currentAgent = appState.agent;

    if (currentAgent == null) return;

    final updatedAgent = currentAgent.copyWith(
      fullName: _nameController.text.trim(),
      services: _selectedServices.toList(),
      serviceArea: _serviceArea.isNotEmpty ? _serviceArea : 'Amritsar, Punjab',
      isOnline: true,
      yearsExperience: int.tryParse(_experienceController.text) ?? 5,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
    );

    await appState.updateProfile(updatedAgent);

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: _previousStep,
              )
            : null,
        title: const Text('Partner Onboarding'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Step ${_currentStep + 1} of 3',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Subtle Progress bar
          LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            backgroundColor: AppColors.surfaceLight,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 3,
          ),

          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPersonalDetailsStep(),
                _buildServicesStep(),
                _buildLocationStep(),
              ],
            ),
          ),

          // Bottom button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Consumer<AppState>(
              builder: (context, appState, _) {
                return SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: appState.isLoading ? null : _nextStep,
                    child: appState.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(_currentStep == 2
                            ? 'Complete Setup & Go Online →'
                            : 'Continue →'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Details',
            style: AppTextStyles.headingMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Provide your details to register as a certified service partner',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Avatar Icon
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: AppColors.primary,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Name field
          const Text('Full Name *', style: AppTextStyles.labelMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'e.g. Ramesh Kumar',
            ),
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 18),


          // Experience
          const Text('Years of Experience', style: AppTextStyles.labelMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _experienceController,
            decoration: const InputDecoration(
              hintText: 'e.g. 5',
            ),
            keyboardType: TextInputType.number,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 18),

          // Description
          const Text('Short Bio / Expertise', style: AppTextStyles.labelMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              hintText: 'e.g. Expert in residential electrical wiring and appliance repairs',
            ),
            maxLines: 2,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Service Skills',
            style: AppTextStyles.headingMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Select the categories you are certified to provide',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // 3-Column Squircle Grid matching Customer App Screenshot
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ServiceCategory.all.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (context, index) {
              final cat = ServiceCategory.all[index];
              final isSelected = _selectedServices.contains(cat.id);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedServices.remove(cat.id);
                    } else {
                      _selectedServices.add(cat.id);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF0F5FF) : AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 1.5 : 0.8,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: cat.bgColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                cat.icon,
                                color: cat.iconColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check,
                                color: Colors.white, size: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Work Location',
            style: AppTextStyles.headingMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Set your active coverage city & operational radius',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Location detection card
          GestureDetector(
            onTap: () {
              setState(() {
                _locationPermissionGranted = true;
                _serviceArea = 'Amritsar, Punjab';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('📍 Coverage set to Amritsar, Punjab (10 km)'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _locationPermissionGranted
                    ? const Color(0xFFF0FDF4)
                    : AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _locationPermissionGranted
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.border,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _locationPermissionGranted
                          ? AppColors.successLight
                          : AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _locationPermissionGranted
                          ? Icons.check_circle_rounded
                          : Icons.my_location_rounded,
                      size: 26,
                      color: _locationPermissionGranted
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _locationPermissionGranted
                        ? 'Location Configured'
                        : 'Detect Current Location',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _locationPermissionGranted
                          ? AppColors.success
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _serviceArea,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Manual input
          const Text('Or enter area manually', style: AppTextStyles.labelMedium),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              hintText: 'e.g. Amritsar, Punjab',
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
            ),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            onChanged: (value) => _serviceArea = value,
          ),
          const SizedBox(height: 24),

          // Policy note card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You will receive requests within 10 km radius of your selected area. You can modify coverage anytime from Profile.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
