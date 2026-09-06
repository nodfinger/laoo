abstract final class ApiEndpoints {
  // Authentication
  static const String login = '/api/auth/login';
  static const String me = '/api/auth/me';
  static const String postLoginContext = '/api/auth/post-login-context';
  static const String permissions = '/api/auth/permissions';

  // Support / Partner
  static const String partners = '/api/support/partners';

  static String partnerById(int partnerId) => '$partners/$partnerId';

  static String partnerStatus(int partnerId) => '$partners/$partnerId/status';
}
