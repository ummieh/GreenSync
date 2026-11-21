enum UserRole { user, vendor, admin }

enum ApprovalStatus { pending, approved, rejected }

/// Turns the text the database sends back ("vendor") into an enum value.
T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
