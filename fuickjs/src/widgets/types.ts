export interface Offset {
  dx: number;
  dy: number;
}

export interface Size {
  width: number;
  height: number;
}

export interface EdgeInsets {
  left?: number;
  top?: number;
  right?: number;
  bottom?: number;
  all?: number;
  vertical?: number;
  horizontal?: number;
}

export interface BoxDecoration {
  color?: string;
  borderRadius?:
  | number
  | {
    topLeft?: number;
    topRight?: number;
    bottomLeft?: number;
    bottomRight?: number;
  };
  border?: {
    color?: string;
    width?: number;
  };
  boxShadow?: {
    color?: string;
    blurRadius?: number;
    offset?: {
      dx?: number;
      dy?: number;
    };
  };
}

export interface BoxConstraints {
  minWidth?: number;
  maxWidth?: number;
  minHeight?: number;
  maxHeight?: number;
}

export interface BaseProps {
  key?: string | number;
  children?: import('react').ReactNode;
  refId?: string;
  isBoundary?: boolean;
}

export interface WidgetProps extends BaseProps {
  padding?: number | EdgeInsets;
  margin?: number | EdgeInsets;
}
