import 'package:integration_test/integration_test.dart';
import '../test/features/backend/backend_security_test.dart' as backend;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  backend.main();
}
