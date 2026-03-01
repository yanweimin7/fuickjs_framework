const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';

/**
 * Encodes a string to Base64, supporting Unicode characters by first converting to UTF-8.
 */
export function btoa(input: string): string {
  // Convert string to UTF-8 encoded string (where each char code is 0-255)
  const str = encodeURIComponent(input).replace(/%([0-9A-F]{2})/g, (_match, p1) => {
    return String.fromCharCode(parseInt(p1, 16));
  });

  let output = '';
  for (
    let block = 0, charCode, i = 0, map = chars;
    str.charAt(i | 0) || ((map = '='), i % 1);
    output += map.charAt(63 & (block >> (8 - (i % 1) * 8)))
  ) {
    charCode = str.charCodeAt((i += 3 / 4));
    if (charCode > 0xff) {
      throw new Error("'btoa' failed: The string to be encoded contains characters outside of the Latin1 range.");
    }
    block = (block << 8) | charCode;
  }
  return output;
}

/**
 * Decodes a Base64 string, supporting Unicode characters by treating the result as UTF-8.
 */
export function atob(input: string): string {
  const str = String(input).replace(/[=]+$/, '');
  if (str.length % 4 === 1) {
    throw new Error("'atob' failed: The string to be decoded is not correctly encoded.");
  }

  let binary = '';
  for (
    let bc = 0, bs = 0, buffer, i = 0;
    (buffer = str.charAt(i++));
    ~buffer && ((bs = bc % 4 ? bs * 64 + buffer : buffer), bc++ % 4)
      ? (binary += String.fromCharCode(255 & (bs >> ((-2 * bc) & 6))))
      : 0
  ) {
    buffer = chars.indexOf(buffer);
  }

  // Convert binary string (UTF-8 bytes) back to Unicode string
  try {
    return decodeURIComponent(
      Array.prototype.map
        .call(binary, (c: string) => {
          return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2);
        })
        .join(''),
    );
  } catch (e) {
    // If decode fails, return the binary string as is (likely not UTF-8)
    return binary;
  }
}
