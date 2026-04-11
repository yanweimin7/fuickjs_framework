export interface Performance {
  now(): number;
  timeOrigin: number;
}

const startTime = Date.now();

export const performance: Performance = {
  now: () => Date.now() - startTime,
  timeOrigin: startTime,
};
