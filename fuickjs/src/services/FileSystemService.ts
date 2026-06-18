export interface Stats {
  isFile: () => boolean;
  isDirectory: () => boolean;
  size: number;
  mode: number;
  changed: number;
  modified: number;
  accessed: number;
}

export interface FileSystem {
  // 异步方法
  readFile(path: string, options?: { encoding?: 'utf8' | 'base64' }): Promise<string>;
  writeFile(path: string, data: string, options?: { encoding?: 'utf8' | 'base64' }): Promise<void>;
  unlink(path: string): Promise<void>;
  mkdir(path: string, options?: { recursive?: boolean }): Promise<void>;
  rmdir(path: string, options?: { recursive?: boolean }): Promise<void>;
  readdir(path: string): Promise<string[]>;
  stat(path: string): Promise<Stats>;
  exists(path: string): Promise<boolean>;
  rename(oldPath: string, newPath: string): Promise<void>;
  copyFile(src: string, dest: string): Promise<void>;
  getDirectories(): Promise<Record<string, string>>;
  // 同步方法
  readFileSync(path: string, options?: { encoding?: 'utf8' | 'base64' }): string;
  writeFileSync(path: string, data: string, options?: { encoding?: 'utf8' | 'base64' }): void;
  unlinkSync(path: string): void;
  mkdirSync(path: string, options?: { recursive?: boolean }): void;
  rmdirSync(path: string, options?: { recursive?: boolean }): void;
  readdirSync(path: string): string[];
  statSync(path: string): Stats;
  existsSync(path: string): boolean;
  renameSync(oldPath: string, newPath: string): void;
  copyFileSync(src: string, dest: string): void;
}

export const fs: FileSystem = {
  readFile: async (path: string, options?: { encoding?: 'utf8' | 'base64' }): Promise<string> => {
    return (await dartCallNativeAsync('FileSystem.readFile', {
      path,
      encoding: options?.encoding,
    })) as string;
  },
  writeFile: async (path: string, data: string, options?: { encoding?: 'utf8' | 'base64' }): Promise<void> => {
    await dartCallNativeAsync('FileSystem.writeFile', {
      path,
      data,
      encoding: options?.encoding,
    });
  },
  unlink: async (path: string): Promise<void> => {
    await dartCallNativeAsync('FileSystem.unlink', { path });
  },
  mkdir: async (path: string, options?: { recursive?: boolean }): Promise<void> => {
    await dartCallNativeAsync('FileSystem.mkdir', {
      path,
      recursive: options?.recursive,
    });
  },
  rmdir: async (path: string, options?: { recursive?: boolean }): Promise<void> => {
    await dartCallNativeAsync('FileSystem.rmdir', {
      path,
      recursive: options?.recursive,
    });
  },
  readdir: async (path: string): Promise<string[]> => {
    return (await dartCallNativeAsync('FileSystem.readdir', {
      path,
    })) as string[];
  },
  stat: async (path: string): Promise<Stats> => {
    const raw = (await dartCallNativeAsync('FileSystem.stat', {
      path,
    })) as any;
    if (!raw) throw new Error(`File not found: ${path}`);
    return {
      ...raw,
      isFile: () => raw.isFile,
      isDirectory: () => raw.isDirectory,
    };
  },
  exists: async (path: string): Promise<boolean> => {
    return (await dartCallNativeAsync('FileSystem.exists', {
      path,
    })) as boolean;
  },
  rename: async (oldPath: string, newPath: string): Promise<void> => {
    await dartCallNativeAsync('FileSystem.rename', { oldPath, newPath });
  },
  copyFile: async (src: string, dest: string): Promise<void> => {
    await dartCallNativeAsync('FileSystem.copyFile', { src, dest });
  },
  getDirectories: async (): Promise<Record<string, string>> => {
    return (await dartCallNativeAsync('FileSystem.getDirectories', {})) as Record<string, string>;
  },
  readFileSync: (path: string, options?: { encoding?: 'utf8' | 'base64' }): string => {
    return dartCallNative('FileSystem.readFileSync', { path, encoding: options?.encoding }) as string;
  },
  writeFileSync: (path: string, data: string, options?: { encoding?: 'utf8' | 'base64' }): void => {
    dartCallNative('FileSystem.writeFileSync', { path, data, encoding: options?.encoding });
  },
  unlinkSync: (path: string): void => {
    dartCallNative('FileSystem.unlinkSync', { path });
  },
  mkdirSync: (path: string, options?: { recursive?: boolean }): void => {
    dartCallNative('FileSystem.mkdirSync', { path, recursive: options?.recursive });
  },
  rmdirSync: (path: string, options?: { recursive?: boolean }): void => {
    dartCallNative('FileSystem.rmdirSync', { path, recursive: options?.recursive });
  },
  readdirSync: (path: string): string[] => {
    return dartCallNative('FileSystem.readdirSync', { path }) as string[];
  },
  statSync: (path: string): Stats => {
    const raw = dartCallNative('FileSystem.statSync', { path }) as any;
    if (!raw) throw new Error(`File not found: ${path}`);
    return {
      ...raw,
      isFile: () => raw.isFile,
      isDirectory: () => raw.isDirectory,
    };
  },
  existsSync: (path: string): boolean => {
    return dartCallNative('FileSystem.existsSync', { path }) as boolean;
  },
  renameSync: (oldPath: string, newPath: string): void => {
    dartCallNative('FileSystem.renameSync', { oldPath, newPath });
  },
  copyFileSync: (src: string, dest: string): void => {
    dartCallNative('FileSystem.copyFileSync', { src, dest });
  },
};
