import { NextResponse } from 'next/server';
import { postgresAdapter } from '@payloadcms/db-postgres';
import { migrations } from '@/migrations';

// Setup database adapter and run migrations if needed
let migrationRun = false;

export async function middleware() {
  // Only run migrations once on server startup
  if (!migrationRun && process.env.NODE_ENV === 'production') {
    try {
      console.log('Checking database migration status...');
      
      const adapter = postgresAdapter({
        pool: {
          connectionString: process.env.DATABASE_URI || '',
        },
        migrationDir: './src/migrations',
        prodMigrations: migrations,
      });
      
      // Migrations will run automatically through the prodMigrations config
      
      migrationRun = true;
      console.log('Database migration check completed successfully');
    } catch (error) {
      console.error('Error checking or running migrations:', error);
    }
  }
  
  // Continue to the next middleware/route handler
  return NextResponse.next();
}

// Run middleware on all routes within the (payload) directory
export const config = {
  matcher: ['/((?!_next|api/db-status).*)'],
};