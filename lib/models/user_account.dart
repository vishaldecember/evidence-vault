/// Signed-in user account preserved across vault resets.
class UserAccount {
  const UserAccount({
    required this.userId,
    required this.name,
    required this.email,
    this.subscriptionTier = 'Free',
    this.onboardingComplete = true,
    this.preferences = const UserPreferences(),
  });

  final String userId;
  final String name;
  final String email;
  final String subscriptionTier;
  final bool onboardingComplete;
  final UserPreferences preferences;

  UserAccount copyWith({
    String? name,
    String? email,
    String? subscriptionTier,
    bool? onboardingComplete,
    UserPreferences? preferences,
  }) {
    return UserAccount(
      userId: userId,
      name: name ?? this.name,
      email: email ?? this.email,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      preferences: preferences ?? this.preferences,
    );
  }
}

class UserPreferences {
  const UserPreferences({
    this.notificationsEnabled = true,
    this.biometricsEnabled = false,
  });

  final bool notificationsEnabled;
  final bool biometricsEnabled;

  UserPreferences copyWith({
    bool? notificationsEnabled,
    bool? biometricsEnabled,
  }) {
    return UserPreferences(
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
    );
  }
}
