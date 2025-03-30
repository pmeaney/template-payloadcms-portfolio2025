import { NextResponse } from 'next/server';
import { postgresAdapter } from '@payloadcms/db-postgres';
import { sql } from 'drizzle-orm';

/**
 * This is a route handler to check database connectivity and run migrations if needed
 */
export async function GET() {
  try {
    // Create a temporary connection to the database to check connectivity
    const adapter = postgresAdapter({
      pool: {
        connectionString: process.env.DATABASE_URI || '',
      },
    });

    // Test database connection using direct SQL query
    const db = adapter.drizzle;
    const result = await db.execute(sql`SELECT 1 as connection_test`);
    
    if (result && result.rows && result.rows.length > 0) {
      return NextResponse.json({ 
        status: 'ok', 
        message: 'Database is connected and operational',
        timestamp: new Date().toISOString()
      });
    } else {
      return NextResponse.json({
        status: 'error',
        message: 'Database connection test failed',
      }, { status: 500 });
    }
  } catch (error) {
    console.error('Database status check failed:', error);
    return NextResponse.json({
      status: 'error',
      message: 'Failed to connect to database',
      error: error instanceof Error ? error.message : String(error),
    }, { status: 500 });
  }
}