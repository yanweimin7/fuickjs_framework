import React, { ReactNode } from 'react';
import { BaseWidget } from './BaseWidget';
import { WidgetProps } from './types';

export interface VideoPlayerProps extends WidgetProps {
  url?: string;
  asset?: string;
  autoPlay?: boolean;
  looping?: boolean;
  showControls?: boolean;
  muted?: boolean;
  onInitialized?: (info: { duration: number; size: { width: number; height: number } }) => void;
  onVideoEnd?: () => void;
  onPause?: () => void;
  onError?: (error: { error: string }) => void;
}

export class VideoPlayer extends BaseWidget<VideoPlayerProps> {
  protected get widgetType(): string {
    return 'VideoPlayer';
  }

  play() {
    this.callNativeCommand('play');
  }

  pause() {
    this.callNativeCommand('pause');
  }

  stop() {
    this.callNativeCommand('stop');
  }

  seekTo(position: number) {
    this.callNativeCommand('seekTo', { position });
  }

  setVolume(volume: number) {
    this.callNativeCommand('setVolume', { volume });
  }

  setLooping(looping: boolean) {
    this.callNativeCommand('setLooping', { looping });
  }

  setPlaybackSpeed(speed: number) {
    this.callNativeCommand('setPlaybackSpeed', { speed });
  }

  render(): ReactNode {
    return React.createElement('VideoPlayer', {
      ...this.props,
      refId: this.scopedRefId,
    });
  }
}
