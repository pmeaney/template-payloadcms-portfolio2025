import migrationData from './20250330_160336.json';

export const up = async (): Promise<any> => {
  return migrationData;
};

export const down = async (): Promise<any> => {
  return null;
};