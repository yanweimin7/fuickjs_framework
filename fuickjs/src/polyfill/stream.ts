import { EventEmitter } from 'events';
import { Readable, Writable, Duplex, Transform } from 'stream-browserify';
import globalAny from './global';

if (!(globalAny as any).EventEmitter) {
  (globalAny as any).EventEmitter = EventEmitter;
}

if (!(globalAny as any).Readable) {
  (globalAny as any).Readable = Readable;
}
if (!(globalAny as any).Writable) {
  (globalAny as any).Writable = Writable;
}
if (!(globalAny as any).Duplex) {
  (globalAny as any).Duplex = Duplex;
}
if (!(globalAny as any).Transform) {
  (globalAny as any).Transform = Transform;
}
