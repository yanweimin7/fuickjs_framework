import './crypto-random';
import './process';
import './buffer';
import './crypto';
import './text';
import './structured-clone';
import { setupGlobals } from './globals';

setupGlobals();

// Must load AFTER setupGlobals(), because the timeout wrapper relies on the
// setTimeout/clearTimeout polyfills installed there.
import './native-async-timeout';
