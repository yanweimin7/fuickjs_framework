import React from 'react';

class ComponentStore {
    private static instance: ComponentStore;
    private components: Map<string, React.ReactNode> = new Map();
    private counter = 0;

    private constructor() {}

    public static getInstance(): ComponentStore {
        if (!ComponentStore.instance) {
            ComponentStore.instance = new ComponentStore();
        }
        return ComponentStore.instance;
    }

    public register(component: React.ReactNode): string {
        const id = `cmp_${Date.now()}_${this.counter++}`;
        this.components.set(id, component);
        return id;
    }

    public get(id: string): React.ReactNode | undefined {
        return this.components.get(id);
    }

    public remove(id: string): void {
        this.components.delete(id);
    }
}

export default ComponentStore;
