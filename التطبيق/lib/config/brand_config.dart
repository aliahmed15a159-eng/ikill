import 'package:flutter/material.dart';

/// White-label offline defaults, overridden by validated public brand_config.
/// Branding is NOT a tenant authorization boundary; Supabase membership/RLS is.
@immutable
class BrandConfig {
  final String companyName;
  final String logoAsset;
  final String darkLogoAsset;
  final Color primaryColor;
  final Color secondaryColor;
  final String emergencyPhone;
  final String email;
  final String currencyCode;
  final bool emergencyAvailable247;

  const BrandConfig({
    required this.companyName,
    required this.logoAsset,
    required this.darkLogoAsset,
    required this.primaryColor,
    required this.secondaryColor,
    required this.emergencyPhone,
    required this.email,
    required this.currencyCode,
    this.emergencyAvailable247 = true,
  });

  /// Override using --dart-define / --dart-define-from-file for each brand.
  /// Add any alternate logo assets to pubspec.yaml in a later integration phase.
  static const current = BrandConfig(
    companyName: String.fromEnvironment('BRAND_NAME', defaultValue: 'iKILL'),
    logoAsset: String.fromEnvironment('BRAND_LOGO',
        defaultValue: 'assets/images/ikill-logo-transparent.png'),
    darkLogoAsset: String.fromEnvironment('BRAND_DARK_LOGO',
        defaultValue: 'assets/images/ikill-logo-dark.png'),
    primaryColor: Color(int.fromEnvironment('BRAND_PRIMARY_ARGB',
        defaultValue: 0xFF0A4D3C)),
    secondaryColor: Color(int.fromEnvironment('BRAND_SECONDARY_ARGB',
        defaultValue: 0xFF052015)),
    emergencyPhone: String.fromEnvironment('BRAND_EMERGENCY_PHONE',
        defaultValue: '01020019042'),
    email: String.fromEnvironment('BRAND_EMAIL', defaultValue: 'info@ikill.net'),
    currencyCode: String.fromEnvironment('BRAND_CURRENCY', defaultValue: 'EGP'),
    emergencyAvailable247: bool.fromEnvironment('BRAND_EMERGENCY_247',
        defaultValue: true),
  );
}
