import * as migration_20250330_160336 from './20250330_160336';

export const migrations = [
  {
    up: migration_20250330_160336.up,
    down: migration_20250330_160336.down,
    name: '20250330_160336'
  },
];
