import 'package:flutter/material.dart';
import 'theme.dart';
import '../screens/customer/customers.dart';

class AppSideDrawer extends StatefulWidget {
  final String username;
  final bool registrationExpanded;

  const AppSideDrawer({
    super.key,
    required this.username,
    this.registrationExpanded = false,
  });

  @override
  State<AppSideDrawer> createState() => _AppSideDrawerState();
}

class _AppSideDrawerState extends State<AppSideDrawer> {
  bool _registrationExpanded = false;

  @override
  void initState() {
    super.initState();
    _registrationExpanded = widget.registrationExpanded;
  }

  // ── Registration sub-items ─────────────────────────────────────────────────
  final List<_DrawerMenuItem> _registrationItems = [
    _DrawerMenuItem(icon: Icons.apartment_rounded,        label: 'Department'),
    _DrawerMenuItem(icon: Icons.person_outline_rounded,   label: 'Customer'),
    _DrawerMenuItem(icon: Icons.badge_outlined,           label: 'Employee'),
    _DrawerMenuItem(icon: Icons.handshake_outlined,       label: 'Deals'),
    _DrawerMenuItem(icon: Icons.groups_outlined,          label: 'Teams'),
    _DrawerMenuItem(icon: Icons.fingerprint_rounded,      label: 'Attendance Machines'),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.of(context).size.width * 0.78,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────
            _buildHeader(),

            const SizedBox(height: 8),

            // ── Menu Items ────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Registration expandable section
                  _buildRegistrationSection(),

                  const SizedBox(height: 8),

                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(color: AppColors.borderLight, thickness: 1),
                  ),
                ],
              ),
            ),

            // ── Footer ────────────────────────────────────────────────────
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.layers_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Core',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    TextSpan(
                      text: 'micron',
                      style: TextStyle(
                        color: Color(0xFFAAD4FF),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Avatar + username
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.30),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.username.isNotEmpty
                        ? widget.username[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'CRM User',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Registration expandable section ────────────────────────────────────────
  Widget _buildRegistrationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header (tap to expand/collapse)
        InkWell(
          onTap: () =>
              setState(() => _registrationExpanded = !_registrationExpanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: _registrationExpanded
                    ? AppColors.primaryLight
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _registrationExpanded
                          ? AppColors.primary
                          : const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.app_registration_rounded,
                      size: 17,
                      color: _registrationExpanded
                          ? Colors.white
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Registration',
                      style: TextStyle(
                        color: _registrationExpanded
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _registrationExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _registrationExpanded
                          ? AppColors.primary
                          : AppColors.iconDefault,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Expandable sub-items
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: _registrationExpanded
              ? Padding(
                  padding: const EdgeInsets.only(left: 28, right: 16),
                  child: Column(
                    children: _registrationItems
                        .map((item) => _buildSubItem(item))
                        .toList(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ── Sub-item tile ───────────────────────────────────────────────────────────
  Widget _buildSubItem(_DrawerMenuItem item) {
    return InkWell(
      onTap: () {
        Navigator.pop(context); // close drawer first
        switch (item.label) {
          case 'Customer':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CustomersPage(username: widget.username),
              ),
            );
            break;
          // TODO: Add navigation for other items as pages are created
          default:
            break;
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              // Connector line + dot
              Column(
                children: [
                  Container(
                    width: 1.5,
                    height: 10,
                    color: AppColors.border,
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.5),
                    ),
                  ),
                  Container(
                    width: 1.5,
                    height: 10,
                    color: AppColors.border,
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Icon(
                item.icon,
                size: 18,
                color: AppColors.textLabel,
              ),
              const SizedBox(width: 10),
              Text(
                item.label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Footer ──────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      child: Text(
        '© ${DateTime.now().year} Coremicron CRM',
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ── Menu item model ────────────────────────────────────────────────────────
class _DrawerMenuItem {
  final IconData icon;
  final String label;

  const _DrawerMenuItem({required this.icon, required this.label});
}