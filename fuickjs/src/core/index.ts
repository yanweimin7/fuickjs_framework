export * from './renderer';
export * from './page_render';
export * from './PageContext';
export * from './ErrorBoundary';
export * from './ErrorHandler';
// 资源路径解析：供带资源属性的组件（含三方扩展组件）在 render 层调用，
// 把 assets/ 下相对路径转为 bundle 内绝对路径。
export { resolveBundleAssetPath } from './node';
