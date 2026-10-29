String returnLocation(String? value) {
  final uri = value == null ? null : Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      ['/auth', '/onboarding', '/recovery', '/welcome'].contains(uri.path)) {
    return '/map';
  }
  return uri.toString();
}

String? authDestination({
  required bool configured,
  required bool signedIn,
  required bool recovering,
  required bool onboarded,
  required String location,
}) {
  if (!configured) return location == '/welcome' ? null : '/welcome';
  if (recovering) return location == '/recovery' ? null : '/recovery';
  if (!signedIn) {
    if (location == '/auth') return null;
    return '/auth?next=${Uri.encodeComponent(location)}';
  }
  if (!onboarded && location != '/onboarding') return '/onboarding';
  if (onboarded &&
      (location == '/auth' ||
          location == '/welcome' ||
          location == '/recovery' ||
          location == '/onboarding')) {
    return '/map';
  }
  return null;
}
