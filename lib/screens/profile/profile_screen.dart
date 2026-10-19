import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:service_wala_business/config/constants.dart';
import 'package:service_wala_business/config/theme.dart';
import 'package:service_wala_business/models/agent_profile.dart';
import 'package:service_wala_business/providers/app_state.dart';
import 'package:service_wala_business/screens/auth/login_screen.dart';

/// Screen displaying the agent's profile, KYC status, services, and app settings
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final agent = appState.agent;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Partner Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            onPressed: () => _handleLogout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Agent Info Card with Edit Profile action
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 0.8),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _showChangeProfilePicDialog(context, agent),
                    child: Stack(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
                          ),
                          child: ClipOval(
                            child: agent?.profileImage != null && agent!.profileImage!.isNotEmpty
                                ? Image.network(
                                    agent.profileImage!,
                                    fit: BoxFit.cover,
                                    width: 84,
                                    height: 84,
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: Text(
                                        agent.fullName.isNotEmpty
                                            ? agent.fullName.substring(0, 1).toUpperCase()
                                            : 'P',
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      agent?.fullName.isNotEmpty == true
                                          ? agent!.fullName.substring(0, 1).toUpperCase()
                                          : 'P',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        agent?.fullName.isNotEmpty == true
                            ? agent!.fullName
                            : 'Service Partner',
                        style: AppTextStyles.headingSmall,
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified,
                          size: 16, color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${agent?.rating.toStringAsFixed(1) ?? '4.9'} ★ (${agent?.reviewCount ?? 128} Reviews) • ${agent?.yearsExperience ?? 5} Yrs Exp',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '📍 ${agent?.serviceArea ?? "Amritsar, Punjab"} • 📞 ${agent?.phone ?? "+91 98765 43210"}',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => _showEditProfileDialog(context, agent),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Personal Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 0.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Availability Status Toggle Tile
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border, width: 0.8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (agent?.isOnline ?? true)
                          ? AppColors.successLight
                          : AppColors.surfaceLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      color: (agent?.isOnline ?? true)
                          ? AppColors.success
                          : AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (agent?.isOnline ?? true)
                              ? 'Active & Receiving Bookings'
                              : 'Offline / Unavailable',
                          style: AppTextStyles.labelMedium,
                        ),
                        Text(
                          (agent?.isOnline ?? true)
                              ? 'Customers can book your local services'
                              : 'You are currently hidden from requests',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: agent?.isOnline ?? true,
                    activeTrackColor: AppColors.successLight,
                    activeThumbColor: AppColors.success,
                    inactiveTrackColor: AppColors.border,
                    inactiveThumbColor: AppColors.textMuted,
                    onChanged: (_) => appState.toggleOnlineStatus(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Service Location Section
            _buildSectionCard(
              title: 'Service Location',
              trailing: 'Edit Location',
              onTrailingTap: () => _showEditLocationDialog(context, agent),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          agent?.serviceArea?.isNotEmpty == true
                              ? agent!.serviceArea!
                              : 'Amritsar, Punjab',
                          style: AppTextStyles.labelMedium,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Primary base city & active matching area',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Services & Skills Offered
            _buildSectionCard(
              title: 'Active Service Skills',
              trailing: 'Manage',
              onTrailingTap: () => _showManageServicesDialog(context, agent),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (agent?.services.isNotEmpty == true
                        ? agent!.services
                        : ['electrician', 'plumbing', 'ac_repair'])
                    .map((serviceId) {
                  final cat = ServiceCategory.findById(serviceId);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: cat?.bgColor ?? AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.border, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat?.icon ?? Icons.build_rounded,
                            size: 16,
                            color: cat?.iconColor ?? AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          cat?.name ?? serviceId,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Verification & KYC Badges
            _buildSectionCard(
              title: 'KYC & Partner Verification',
              child: Column(
                children: [
                  _kycItem('Aadhaar Card Verification', 'Verified ✓',
                      Icons.verified_user_rounded, AppColors.success),
                  const Divider(height: 20),
                  _kycItem('PAN Card Status', 'Verified ✓',
                      Icons.credit_card_rounded, AppColors.success),
                  const Divider(height: 20),
                  _kycItem('Background & Police Clearance', 'Verified ✓',
                      Icons.security_rounded, AppColors.success),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bank Account & Payouts
            _buildSectionCard(
              title: 'Payout Bank & UPI',
              trailing: 'Edit',
              onTrailingTap: () => _showEditBankDialog(context),
              child: Column(
                children: [
                  _bankRow(Icons.account_balance_rounded, 'HDFC Bank Ltd.',
                      'A/C: •••• •••• 8912 (Primary Settlement)'),
                  const SizedBox(height: 12),
                  _bankRow(Icons.qr_code_2_rounded, 'UPI Direct Settlement',
                      'partner@okhdfcbank (Instant)'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // App Settings & Preferences
            _buildSectionCard(
              title: 'Settings & Support',
              child: Column(
                children: [
                  _settingsItem(
                    Icons.notifications_none_rounded,
                    'Notification Preferences',
                    onTap: () => _showNotificationSettings(context),
                  ),
                  const Divider(height: 20),
                  _settingsItem(
                    Icons.support_agent_rounded,
                    'Partner Help & Support Desk',
                    onTap: () => _showSupportDialog(context),
                  ),
                  const Divider(height: 20),
                  _settingsItem(
                    Icons.policy_outlined,
                    'Partner Terms & Agreement',
                    onTap: () => _showTermsDialog(context),
                  ),
                  const Divider(height: 20),
                  _settingsItem(
                    Icons.info_outline_rounded,
                    'ServiceWala Partner App v1.0.0',
                    onTap: () => _showAppInfoDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _handleLogout(context),
                icon: const Icon(Icons.logout_rounded,
                    color: AppColors.error, size: 18),
                label: const Text(
                  'Logout Account',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(AgentProfile? agent) {
    return Center(
      child: Text(
        agent?.fullName.isNotEmpty == true
            ? agent!.fullName.substring(0, 1).toUpperCase()
            : 'P',
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AgentProfile? agent) {
    final nameController = TextEditingController(text: agent?.fullName ?? '');
    final phoneController = TextEditingController(text: agent?.phone ?? '');
    final cityController =
        TextEditingController(text: agent?.serviceArea ?? 'Amritsar, Punjab');
    final formKey = GlobalKey<FormState>();
    String? currentAvatarUrl = agent?.profileImage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Edit Personal Details'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Profile Picture Section inside Edit Profile ---
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: (currentAvatarUrl != null &&
                                    currentAvatarUrl!.isNotEmpty)
                                ? Image.network(
                                    currentAvatarUrl!,
                                    fit: BoxFit.cover,
                                    width: 84,
                                    height: 84,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _buildAvatarFallback(agent),
                                  )
                                : _buildAvatarFallback(agent),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
                            onTap: () => _showAvatarPickerSheet(
                              ctx,
                              currentUrl: currentAvatarUrl,
                              onSelected: (newUrl) {
                                setDialogState(() {
                                  currentAvatarUrl = newUrl;
                                });
                              },
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => _showAvatarPickerSheet(
                      ctx,
                      currentUrl: currentAvatarUrl,
                      onSelected: (newUrl) {
                        setDialogState(() {
                          currentAvatarUrl = newUrl;
                        });
                      },
                    ),
                    icon: const Icon(Icons.photo_camera_outlined, size: 14),
                    label: const Text(
                      'Change Photo',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Name required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) =>
                        v == null || v.trim().length < 10
                            ? 'Valid phone required'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cityController,
                    decoration: const InputDecoration(
                      labelText: 'City / Service Area',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  final updated = (agent ??
                          const AgentProfile(
                              id: 'agent_001', fullName: '', phone: ''))
                      .copyWith(
                    fullName: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    serviceArea: cityController.text.trim(),
                    profileImage: currentAvatarUrl,
                  );
                  context.read<AppState>().updateProfile(updated);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                          '✅ Profile details and photo updated successfully!'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Save Details'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditLocationDialog(BuildContext context, AgentProfile? agent) {
    final locationController = TextEditingController(
      text: agent?.serviceArea?.isNotEmpty == true
          ? agent!.serviceArea!
          : 'Amritsar, Punjab',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Edit Service Location'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Specify your operational city or area to match with nearby customer requests.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: locationController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'City / Service Area',
                  hintText: 'e.g. Amritsar, Punjab',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Location cannot be empty' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                final updatedLocation = locationController.text.trim();
                final updated = (agent ??
                        const AgentProfile(
                            id: 'agent_001', fullName: '', phone: ''))
                    .copyWith(serviceArea: updatedLocation);
                context.read<AppState>().updateProfile(updated);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Service location updated to "$updatedLocation"'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: const Text('Save Location'),
          ),
        ],
      ),
    );
  }

  void _showManageServicesDialog(BuildContext context, AgentProfile? agent) {
    final selectedServices = List<String>.from(agent?.services ?? ['electrician', 'plumbing']);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Manage Service Skills'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: ServiceCategory.all.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final service = ServiceCategory.all[index];
                final isSelected = selectedServices.contains(service.id);

                return CheckboxListTile(
                  value: isSelected,
                  title: Text(service.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  secondary: Icon(service.icon, color: service.iconColor, size: 20),
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        selectedServices.add(service.id);
                      } else {
                        selectedServices.remove(service.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (agent != null) {
                  final updated = agent.copyWith(services: selectedServices);
                  context.read<AppState>().updateProfile(updated);
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('✅ Service skills updated!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              child: const Text('Save Skills'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBankDialog(BuildContext context) {
    final bankController = TextEditingController(text: 'HDFC Bank Ltd.');
    final accountController = TextEditingController(text: '891234567890');
    final upiController = TextEditingController(text: 'partner@okhdfcbank');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Edit Payout Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bankController,
              decoration: const InputDecoration(labelText: 'Bank Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: accountController,
              decoration: const InputDecoration(labelText: 'Account Number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: upiController,
              decoration: const InputDecoration(labelText: 'UPI ID for Instant Payouts'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('✅ Bank and UPI details saved for settlement.'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Save Account'),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Notification Preferences'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile.adaptive(
              value: true,
              onChanged: (_) {},
              title: const Text('New Job Radar Alerts', style: TextStyle(fontSize: 14)),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile.adaptive(
              value: true,
              onChanged: (_) {},
              title: const Text('Customer Chat Messages', style: TextStyle(fontSize: 14)),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile.adaptive(
              value: true,
              onChanged: (_) {},
              title: const Text('Instant Settlement SMS', style: TextStyle(fontSize: 14)),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Partner Support Desk'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need assistance with active bookings or settlements?', style: AppTextStyles.bodyMedium),
            SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.phone, color: AppColors.primary, size: 18),
                SizedBox(width: 10),
                Text('Partner Helpline: 1800-SERVICE-WALA', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.email_outlined, color: AppColors.primary, size: 18),
                SizedBox(width: 10),
                Text('support@servicewala.in', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Partner Agreement'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1. Zero platform fee during partner onboarding phase.\n\n'
                '2. Transparent direct settlements for verified completed jobs.\n\n'
                '3. Professional code of conduct and on-time arrival guaranteed to customers.',
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showAppInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('About ServiceWala Partner'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0 (Hackathon Build)', style: AppTextStyles.labelMedium),
            SizedBox(height: 6),
            Text('Unified Platform: Customer & Agent App Shared Backend.', style: AppTextStyles.bodySmall),
            SizedBox(height: 6),
            Text('Status: Production-Ready Foundation', style: AppTextStyles.bodySmall),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    String? trailing,
    VoidCallback? onTrailingTap,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTextStyles.labelLarge),
              if (trailing != null)
                GestureDetector(
                  onTap: onTrailingTap,
                  child: Text(
                    trailing,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _kycItem(
      String title, String status, IconData icon, Color statusColor) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: AppTextStyles.bodyMedium),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _bankRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: AppColors.surfaceLight,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelMedium),
              Text(subtitle, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingsItem(IconData icon, String title, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: AppTextStyles.bodyMedium),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _showChangeProfilePicDialog(BuildContext context, AgentProfile? agent) {
    _showAvatarPickerSheet(
      context,
      currentUrl: agent?.profileImage,
      onSelected: (newUrl) {
        context.read<AppState>().updateProfileImage(newUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully! ✓'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _showAvatarPickerSheet(
    BuildContext context, {
    String? currentUrl,
    required ValueChanged<String> onSelected,
  }) {
    final urlController = TextEditingController(text: currentUrl ?? '');

    final avatarPresets = [
      {
        'label': 'AC Specialist',
        'url':
            'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=200&auto=format&fit=crop&q=80',
      },
      {
        'label': 'Electrician',
        'url':
            'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=200&auto=format&fit=crop&q=80',
      },
      {
        'label': 'Plumbing Pro',
        'url':
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
      },
      {
        'label': 'Home Cleaner',
        'url':
            'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=200&auto=format&fit=crop&q=80',
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Select Profile Picture',
                  style: AppTextStyles.headingSmall),
              const SizedBox(height: 4),
              const Text(
                'Upload a photo from your device or choose a specialist avatar.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 18),

              // Device Camera & Gallery Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetCtx);
                        await _pickAndUploadImage(
                          context,
                          ImageSource.camera,
                          onSelected,
                        );
                      },
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Take Photo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                            color: AppColors.primary, width: 0.8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetCtx);
                        await _pickAndUploadImage(
                          context,
                          ImageSource.gallery,
                          onSelected,
                        );
                      },
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('From Gallery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                            color: AppColors.primary, width: 0.8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text(
                'Avatar Presets:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: avatarPresets.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final preset = avatarPresets[index];
                    final isSelected = urlController.text == preset['url'];
                    return InkWell(
                      onTap: () {
                        setSheetState(() {
                          urlController.text = preset['url']!;
                        });
                      },
                      borderRadius: BorderRadius.circular(35),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundImage: NetworkImage(preset['url']!),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                'Or Paste Custom Image URL:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  hintText: 'https://...',
                  prefixIcon: const Icon(Icons.link, size: 20),
                  suffixIcon: urlController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () =>
                              setSheetState(() => urlController.clear()),
                        )
                      : null,
                ),
                onChanged: (_) => setSheetState(() {}),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final chosenUrl = urlController.text.trim();
                        if (chosenUrl.isNotEmpty) {
                          onSelected(chosenUrl);
                        }
                        Navigator.pop(sheetCtx);
                      },
                      child: const Text('Apply Photo'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(
    BuildContext context,
    ImageSource source,
    ValueChanged<String> onSelected,
  ) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final ext = pickedFile.name.contains('.')
          ? pickedFile.name.split('.').last
          : 'jpg';

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Uploading photo to cloud storage...'),
            ],
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      try {
        final publicUrl =
            await context.read<AppState>().uploadAvatarImage(bytes, ext);
        if (publicUrl != null) {
          onSelected(publicUrl);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Profile photo uploaded successfully!'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('[ProfileScreen] Supabase storage upload note: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cloud storage note: $e. You can also pick a preset avatar or paste a URL.',
              ),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[ProfileScreen] Pick image exception: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access image: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Confirm Logout'),
        content: const Text(
            'Are you sure you want to log out of your ServiceWala Partner account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AppState>().logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(0, 40),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
