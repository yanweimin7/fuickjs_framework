export interface ChooseImageResult {
  tempFilePaths: string[];
  tempFiles: Array<{ path: string; tempFilePath: string; size: number; type: string }>;
}

export interface ChooseVideoResult {
  tempFilePath: string;
  size: number;
  type: string;
}

export class MediaService {
  static async chooseImage(
    count?: number,
    sourceType?: string[],
  ): Promise<ChooseImageResult | null> {
    return (await dartCallNativeAsync('Media.chooseImage', {
      count: count ?? 1,
      sourceType: sourceType ?? ['album', 'camera'],
    })) as ChooseImageResult | null;
  }

  static async chooseVideo(
    sourceType?: string[],
  ): Promise<ChooseVideoResult | null> {
    return (await dartCallNativeAsync('Media.chooseVideo', {
      sourceType: sourceType ?? ['album', 'camera'],
    })) as ChooseVideoResult | null;
  }

  static async previewImage(urls: string[], current?: number): Promise<void> {
    await dartCallNativeAsync('Media.previewImage', {
      urls,
      current: current ?? 0,
    });
  }
}
