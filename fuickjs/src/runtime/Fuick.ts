export const Fuick = {
  /**
   * Expose a JS object to Flutter.
   * The object will be attached to globalThis with the given name,
   * allowing Flutter to invoke its methods using `ctx.invoke(name, method, args)`.
   *
   * @param name The name to expose the object as
   * @param obj The object instance
   */
  expose(name: string, obj: unknown) {
    if (!name) {
      console.error('[Fuick] Expose name cannot be empty');
      return;
    }
    const globalObj = globalThis as unknown as Record<string, unknown>;
    if (globalObj[name]) {
      console.warn(`[Fuick] Overwriting existing global object: ${name}`);
    }
    globalObj[name] = obj;
  },
};
