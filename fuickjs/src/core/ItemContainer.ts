import { PageContainer } from './PageContainer';

/**
 * ItemContainer 是 PageContainer 的轻量子类，专门用于列表项的 reconciler sub-root。
 *
 * 与主 PageContainer 的关键区别：
 * 1. 初始渲染 commit 是空操作 — DSL 由 getItemDSL() 通过 toDsl() 手动提取返回
 * 2. 后续状态变更 commit 发送增量补丁 — 让 Flutter 侧列表项能响应 useState/useEffect 更新
 * 3. 事件回调转发到主 PageContainer — 确保事件派发时能找到回调
 * 4. 共享主 container 的 nextNodeId — 避免 nodeId 冲突
 * 5. toDsl() 从已提交的 Node 树提取 DSL — 给 getItemDSL 返回
 */
export class ItemContainer extends PageContainer {
  private mainContainer: PageContainer;
  private initialRenderDone: boolean = false;

  constructor(pageId: number, mainContainer: PageContainer) {
    super(pageId);
    this.mainContainer = mainContainer;
  }

  /**
   * 标记初始渲染完成。
   * 由 ListItemManager.getItemDSL() 在 flushSync 后调用。
   * 之后的 commit() 调用将发送增量补丁到 Flutter。
   *
   * 必须同时置 isFirstRender = false：ItemContainer 重写了 commit()，
   * 不会走 PageContainer.commit 里清除 isFirstRender 的逻辑。若不清除，
   * 后续 Node.applyProps 会永远跳过 registerCallbacksRecursive，导致
   * 「函数引用变化但节点自身无 DSL 变化」的更新不重注册回调，
   * 事件 handler 持续引用首帧的旧闭包（stale closure）。
   */
  public markInitialRenderDone(): void {
    this.initialRenderDone = true;
    this.diffStrategy.rendered = true;
    this.isFirstRender = false;
  }

  /**
   * 重写：初始渲染为空操作（DSL 由 toDsl() 手动提取），
   * 后续状态变更发送增量补丁到 Flutter。
   *
   * 原理：列表项的 Node ID 已注册在 Flutter 侧同一个 FuickNodeManager 中，
   * 所以 patchOps 的 UPDATE/INSERT/DELETE 操作可以被正确找到并应用。
   */
  public override commit(): void {
    if (!this.initialRenderDone) {
      // 初始渲染：DSL 由 toDsl() 手动提取，不发送补丁
      this.clear();
      return;
    }

    // 后续状态变更：发送增量补丁到 Flutter
    try {
      if (this.incrementalMode) {
        this.incrementalStrategy.commit();
      } else {
        this.diffStrategy.commit();
      }
    } catch (e) {
      console.error(`[ItemContainer] Error during commit for page ${this.pageId}:`, e);
    } finally {
      this.clear();
    }
  }

  /**
   * 重写：将事件回调注册到主 PageContainer。
   * 这样 Flutter 侧通过 dispatchEvent 派发事件时，能在主 container 中找到回调。
   */
  public override registerCallback(
    nodeId: number | string,
    eventKey: string,
    fn: (...args: unknown[]) => unknown,
  ): void {
    this.mainContainer.registerCallback(nodeId, eventKey, fn);
  }

  /**
   * 重写：从主 PageContainer 注销回调。
   */
  public override unregisterCallback(nodeId: number | string, eventKey: string): void {
    this.mainContainer.unregisterCallback(nodeId, eventKey);
  }

  /**
   * 重写：清理节点回调时，也要清理主 container 中的。
   */
  public override clearNodeCallbacks(nodeId: number | string): void {
    this.mainContainer.clearNodeCallbacks(nodeId);
  }

  /**
   * 重写：从主 container 获取回调。
   */
  public override getCallback(
    nodeId: number | string,
    eventKey: string,
  ): ((...args: unknown[]) => unknown) | undefined {
    return this.mainContainer.getCallback(nodeId, eventKey);
  }

  /**
   * 重写：共享主 container 的 nextNodeId，避免 nodeId 冲突。
   * elementToDsl 路径中自增的 nodeId 会走这里。
   */
  public override get nextNodeId(): number {
    return this.mainContainer.nextNodeId;
  }
  public override set nextNodeId(val: number) {
    this.mainContainer.nextNodeId = val;
  }

  public override get elementToDslNextNodeId(): number {
    return this.mainContainer.elementToDslNextNodeId;
  }
  public override set elementToDslNextNodeId(val: number) {
    this.mainContainer.elementToDslNextNodeId = val;
  }

  /**
   * 从已提交的 Node 树提取 DSL。
   * 在 flushSync + updateContainer 之后调用，此时 root 已是最新提交的 Node。
   */
  public toDsl(): unknown {
    if (!this.root) return null;

    // 对 root 节点，如果只有一个子节点且是"透明"节点（如 Fragment 包装），
    // 直接取其子节点作为 DSL
    const dsl = this.root.toDsl();
    return dsl;
  }
}
