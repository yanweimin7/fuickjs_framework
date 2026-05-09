import { Node } from '../core/node';
import { PageContainer } from '../core/PageContainer';
import { UIService } from '../services/UIService';
import { perfLog } from '../utils/log';

export class DiffStrategy {
  private container: PageContainer;
  public changedNodes: Set<Node> = new Set();
  public rendered: boolean = false;

  constructor(container: PageContainer) {
    this.container = container;
  }

  public markChanged(node: Node | null) {
    if (!node) return;
    let current = node;
    // Walk up until we find a boundary node or hit the root
    while (current.parent && !current.props?.isBoundary) {
      current = current.parent;
    }
    this.changedNodes.add(current);
    if (current === this.container.root) {
      perfLog(`[JS Performance] Root node (id=${current.id}, type=${current.type}) marked as changed!`);
    }
  }

  public clear() {
    this.changedNodes.clear();
  }

  public commit() {
    if (!this.container.root) {
      return;
    }

    if (this.changedNodes.size === 0 && this.rendered) {
      return;
    }

    const commitStart = Date.now();
    const pageId = this.container.pageId;

    const rootChanged = this.container.root && this.changedNodes.has(this.container.root);

    if (!this.rendered || rootChanged) {
      const dslStart = Date.now();
      const dsl = this.container.root?.toDsl();
      const dslEnd = Date.now();
      if (dsl && (dsl as { type: unknown }).type) {
        UIService.renderUI(Number(pageId), dsl);
        this.rendered = true;
        perfLog(
          `[JS Performance] commit(full) page=${pageId} total=${Date.now() - commitStart}ms (dsl=${dslEnd - dslStart}ms)`,
        );
      }
    } else {
      const patches: unknown[] = [];
      const processedNodes = new Set<number | string>();

      // Optimization: Normalize changed nodes (handle flutter-props)
      const normalizedChangedNodes = new Set<Node>();
      for (const node of this.changedNodes) {
        // If a flutter-props node changed, it means its parent (the host component) needs to update
        // to reflect the new property value in its DSL.
        if ((node.type === 'FlutterProps' || node.type === 'flutter-props') && node.parent) {
          normalizedChangedNodes.add(node.parent);
        } else {
          normalizedChangedNodes.add(node);
        }
      }

      // Filter for top-level nodes only (avoid sending redundant child patches)
      const topLevelNodes = new Set<Node>();
      for (const node of normalizedChangedNodes) {
        let isRedundant = false;
        let current = node.parent;
        while (current) {
          if (normalizedChangedNodes.has(current)) {
            isRedundant = true;
            break;
          }
          current = current.parent;
        }
        if (!isRedundant) {
          topLevelNodes.add(node);
        }
      }

      const dslStart = Date.now();
      for (const node of topLevelNodes) {
        if (processedNodes.has(node.id)) continue;

        const dsl = node.toDsl();
        if (dsl) {
          patches.push(dsl);
          processedNodes.add(node.id);
        }
      }
      const dslEnd = Date.now();

      if (patches.length > 0) {
        UIService.patchUI(Number(pageId), patches);
        const changedNodeTypes = Array.from(topLevelNodes)
          .map((n) => n.type)
          .join(', ');
        perfLog(
          `[JS Performance] commit(patchUI) page=${pageId} nodes=${topLevelNodes.size} types=[${changedNodeTypes}] total=${Date.now() - commitStart}ms (dsl=${dslEnd - dslStart}ms)`,
        );
      }
    }

    this.clear();
  }
}
