import 'stomp_handler_test.dart' as stomp_handler_test;
import 'stomp_parser_test.dart' as stomp_parser_test;
import 'stomp_test.dart' as stomp_test;

/// This file is needed to generate coverage for all tests.
/// For some reason the dart coverage library only executes one file and cannot
/// generate coverage for multiple files. At least that was my expierence

void main() {
  stomp_parser_test.main();
  stomp_handler_test.main();
  stomp_test.main();
}
