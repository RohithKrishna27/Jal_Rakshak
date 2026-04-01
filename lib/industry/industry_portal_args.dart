/// Arguments for [IndustryPortalScreen] — use with named route or [MaterialPageRoute].
class IndustryPortalArgs {
  const IndustryPortalArgs({
    required this.adminDisplayName,
    this.userId,
    this.initialTabIndex = 0,
  }) : assert(initialTabIndex >= 0 && initialTabIndex < 4);

  /// Logged-in industry admin name (from Firestore `users/{uid}.name`).
  final String adminDisplayName;

  /// Firebase Auth uid for loading/saving company profile on `users/{uid}`.
  final String? userId;

  /// 0 = Company registration, 1 = Nearest IoT nodes, 2 = Contamination, 3 = Complaints.
  final int initialTabIndex;

  IndustryPortalArgs copyWith({
    String? adminDisplayName,
    String? userId,
    int? initialTabIndex,
  }) {
    return IndustryPortalArgs(
      adminDisplayName: adminDisplayName ?? this.adminDisplayName,
      userId: userId ?? this.userId,
      initialTabIndex: initialTabIndex ?? this.initialTabIndex,
    );
  }
}
