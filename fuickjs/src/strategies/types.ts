export type UpdateOp = {
  type: 1;
  id: number | string;
  props: unknown;
};

export type InsertOp = {
  type: 2;
  parentId: number | string;
  childId: number | string;
  index: number;
  childDsl: unknown;
};

export type RemoveOp = {
  type: 3;
  parentId: number | string;
  childId: number | string;
};

export type MutationOp = UpdateOp | InsertOp | RemoveOp;
