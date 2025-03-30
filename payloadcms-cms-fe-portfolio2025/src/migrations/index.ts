import * as migration_20250330_160336 from './20250330_160336';

// Export migrations in CommonJS format for compatibility
export const migrations = [
  {
    up: migration_20250330_160336.up,
    down: migration_20250330_160336.down,
    name: '20250330_160336'
  },
];

// For CommonJS require compatibility
module.exports = {
  migrations
};