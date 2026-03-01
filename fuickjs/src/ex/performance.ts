export interface Performance {
  now(): number;
  timeOrigin: number;
}

let startTime = Date.now();

export const performance: Performance = {
  now: () => Date.now() - startTime,
  timeOrigin: startTime,
};
