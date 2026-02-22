declare let dartCallNativeAsync: (method: string, args: unknown) => Promise<unknown>;

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
  readFile(
    path: string,
    options?: { encoding?: 'utf8' | 'base64' },
  ): Promise<string>;
  writeFile(
    path: string,
    data: string,
    options?: { encoding?: 'utf8' | 'base64' },
  ): Promise<void>;
  unlink(path: string): Promise<void>;
  mkdir(path: string, options?: { recursive?: boolean }): Promise<void>;
  rmdir(path: string, options?: { recursive?: boolean }): Promise<void>;
  readdir(path: string): Promise<string[]>;
  stat(path: string): Promise<Stats>;
  exists(path: string): Promise<boolean>;
  rename(oldPath: string, newPath: string): Promise<void>;
  copyFile(src: string, dest: string): Promise<void>;
  getDirectories(): Promise<Record<string, string>>;
}

export const fs: FileSystem = {
  readFile: async (
    path: string,
    options?: { encoding?: 'utf8' | 'base64' },
  ): Promise<string> => {
    return (await dartCallNativeAsync('FileSystem.readFile', {
      path,
      encoding: options?.encoding,
    })) as string;
  },
  writeFile: async (
    path: string,
    data: string,
    options?: { encoding?: 'utf8' | 'base64' },
  ): Promise<void> => {
    await dartCallNativeAsync('FileSystem.writeFile', {
      path,
      data,
      encoding: options?.encoding,
    });
  },
  unlink: async (path: string): Promise<void> => {
    await dartCallNativeAsync('FileSystem.unlink', { path });
  },
  mkdir: async (
    path: string,
    options?: { recursive?: boolean },
  ): Promise<void> => {
    await dartCallNativeAsync('FileSystem.mkdir', {
      path,
      recursive: options?.recursive,
    });
  },
  rmdir: async (
    path: string,
    options?: { recursive?: boolean },
  ): Promise<void> => {
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
    return (await dartCallNativeAsync('FileSystem.getDirectories', {})) as Record<
      string,
      string
    >;
  },
};
