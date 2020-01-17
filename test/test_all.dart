import 'stomp_handler_test.dart' as StompHandlerTest;
import 'stomp_parser_test.dart' as StompParserTest;
import 'stomp_test.dart' as StompTest;

/**
 * This file is needed to generate coverage for all tests.
 * For some reason the dart coverage library only executes one file and cannot
 * generate coverage for multiple files. At least that was my expierence
 */
void main() {
  StompParserTest.main();
  StompHandlerTest.main();
  StompTest.main();
}
