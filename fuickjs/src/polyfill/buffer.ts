import { Buffer } from 'buffer';
import globalAny from './global';

if (!(globalAny as any).Buffer) {
  (globalAny as any).Buffer = Buffer;
}
