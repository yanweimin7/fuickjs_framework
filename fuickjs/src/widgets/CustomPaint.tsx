import React, { ReactNode } from 'react';
import { WidgetProps, Offset, Size } from './types';
import { BaseWidget } from './BaseWidget';
import { UIService } from '../services/UIService';

let controllerIdCounter = 1;

export interface Paint {
  color?: string;
  strokeWidth?: number;
  style?: 'fill' | 'stroke';
  strokeCap?: 'butt' | 'round' | 'square';
  strokeJoin?: 'miter' | 'round' | 'bevel';
  isAntiAlias?: boolean;
}

export class Path {
  private operations: unknown[] = [];

  moveTo(x: number, y: number) {
    this.operations.push({ type: 'moveTo', x, y });
  }

  lineTo(x: number, y: number) {
    this.operations.push({ type: 'lineTo', x, y });
  }

  quadraticBezierTo(x1: number, y1: number, x2: number, y2: number) {
    this.operations.push({ type: 'quadraticBezierTo', x1, y1, x2, y2 });
  }

  cubicTo(x1: number, y1: number, x2: number, y2: number, x3: number, y3: number) {
    this.operations.push({ type: 'cubicTo', x1, y1, x2, y2, x3, y3 });
  }

  arcTo(
    rect: { left: number; top: number; width: number; height: number },
    startAngle: number,
    sweepAngle: number,
    forceMoveTo?: boolean,
  ) {
    this.operations.push({ type: 'arcTo', rect, startAngle, sweepAngle, forceMoveTo: forceMoveTo ?? true });
  }

  addRect(rect: { left: number; top: number; width: number; height: number }) {
    this.operations.push({ type: 'addRect', rect });
  }

  addOval(rect: { left: number; top: number; width: number; height: number }) {
    this.operations.push({ type: 'addOval', rect });
  }

  addRRect(rrect: { left: number; top: number; width: number; height: number; radius: number }) {
    this.operations.push({ type: 'addRRect', rrect });
  }

  close() {
    this.operations.push({ type: 'close' });
  }

  serialize() {
    return { operations: this.operations };
  }
}

export class CustomPainter {
  id: number;
  private commands: unknown[] = [];
  private scopedRefId: string | null = null;
  private target: 'painter' | 'foregroundPainter' = 'painter';

  private paintCallback?: (painter: CustomPainter) => void;

  constructor(paintCallback?: (painter: CustomPainter) => void) {
    this.id = controllerIdCounter++;
    this.paintCallback = paintCallback;
    if (this.paintCallback) {
      this.paintCallback(this);
    }
  }

  /**
   * Internal method to bind the painter to a widget instance.
   * Called by CustomPaint widget during render.
   */
  bind(scopedRefId: string, target: 'painter' | 'foregroundPainter') {
    this.scopedRefId = scopedRefId;
    this.target = target;
  }

  save() {
    this.commands.push({ type: 'save' });
  }

  restore() {
    this.commands.push({ type: 'restore' });
  }

  translate(dx: number, dy: number) {
    this.commands.push({ type: 'translate', dx, dy });
  }

  scale(sx: number, sy: number) {
    this.commands.push({ type: 'scale', sx, sy });
  }

  rotate(radians: number) {
    this.commands.push({ type: 'rotate', radians });
  }

  drawLine(p1: Offset, p2: Offset, paint: Paint) {
    this.commands.push({ type: 'drawLine', p1, p2, paint });
  }

  drawRect(rect: { left: number; top: number; width: number; height: number }, paint: Paint) {
    this.commands.push({ type: 'drawRect', rect, paint });
  }

  drawCircle(center: Offset, radius: number, paint: Paint) {
    this.commands.push({ type: 'drawCircle', center, radius, paint });
  }

  drawOval(rect: { left: number; top: number; width: number; height: number }, paint: Paint) {
    this.commands.push({ type: 'drawOval', rect, paint });
  }

  drawArc(
    rect: { left: number; top: number; width: number; height: number },
    startAngle: number,
    sweepAngle: number,
    useCenter: boolean,
    paint: Paint,
  ) {
    this.commands.push({ type: 'drawArc', rect, startAngle, sweepAngle, useCenter, paint });
  }

  drawRRect(rrect: { left: number; top: number; width: number; height: number; radius: number }, paint: Paint) {
    this.commands.push({ type: 'drawRRect', rrect, paint });
  }

  drawPath(path: Path, paint: Paint) {
    this.commands.push({ type: 'drawPath', path: path.serialize(), paint });
  }

  serialize() {
    return this.commands;
  }

  /**
   * Triggers a re-render of the CustomPaint widget to update the canvas.
   * If a builder callback is provided or was passed to constructor, it will be executed
   * to rebuild commands after clearing existing ones.
   */
  repaint(builder?: (painter: CustomPainter) => void) {
    const activeBuilder = builder || this.paintCallback;
    if (activeBuilder) {
      this.commands = [];
      activeBuilder(this);
    }
    if (this.onRepaint) {
      this.onRepaint();
    }
  }

  /**
   * Internal callback to trigger widget update.
   */
  onRepaint?: () => void;

  clear() {
    this.commands = [];
  }
}

export interface CustomPaintProps extends WidgetProps {
  painter?: CustomPainter;
  foregroundPainter?: CustomPainter;
  size?: Size;
  isComplex?: boolean;
  willChange?: boolean;
  child?: ReactNode;
}

export class CustomPaint extends BaseWidget<CustomPaintProps> {
  constructor(props: CustomPaintProps) {
    super(props);
    this.state = { ...this.state, repaintTick: 0 };
  }

  componentDidMount() {
    // Call super only if it exists (though BaseWidget likely has it)
    if (super.componentDidMount) {
      super.componentDidMount();
    }
    this.bindPainter();
  }

  componentDidUpdate(prevProps: CustomPaintProps, prevState: any, snapshot?: any) {
    if (super.componentDidUpdate) {
      super.componentDidUpdate(prevProps, prevState, snapshot);
    }
    this.bindPainter();
  }

  bindPainter() {
    const { painter, foregroundPainter } = this.props;
    if (painter) {
      painter.onRepaint = () => this.forceUpdate();
    }
    if (foregroundPainter) {
      foregroundPainter.onRepaint = () => this.forceUpdate();
    }
  }

  render(): ReactNode {
    const { painter, foregroundPainter, child, ...rest } = this.props;

    if (painter) {
      painter.bind(this.scopedRefId, 'painter');
    }
    if (foregroundPainter) {
      foregroundPainter.bind(this.scopedRefId, 'foregroundPainter');
    }

    // Force re-evaluation of serialized commands
    const painterCommands = painter?.serialize();
    const foregroundPainterCommands = foregroundPainter?.serialize();

    return React.createElement(
      'CustomPaint',
      {
        ...rest,
        refId: this.scopedRefId,
        painter: painterCommands ? [...painterCommands] : undefined, // Create new array reference
        foregroundPainter: foregroundPainterCommands ? [...foregroundPainterCommands] : undefined,
        isBoundary: true,
      },
      child,
    );
  }
}
