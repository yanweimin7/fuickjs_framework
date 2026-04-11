export class ConsoleService {
  static log(message: string) {
    this.console('log', message);
  }

  static warn(message: string) {
    this.console('warn', message);
  }

  static error(message: string) {
    this.console('error', message);
  }

  private static console(level: string, message: string) {
    dartCallNative('Console.console', { level, message });
  }
}
