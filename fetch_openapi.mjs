import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

// Simple dotenv parsing
const envData = fs.readFileSync('.env', 'utf-8');
const env = {};
envData.split('\n').forEach(line => {
  const match = line.match(/^([^=]+)=(.*)$/);
  if (match) {
    env[match[1].trim()] = match[2].trim();
  }
});

async function fetchSchema(name, url, key) {
  console.log(`\n======================================================`);
  console.log(`Fetching OpenAPI Schema for ${name}...`);
  try {
    const response = await fetch(`${url}/rest/v1/?apikey=${key}`, {
      headers: {
        'Authorization': `Bearer ${key}`
      }
    });
    const data = await response.json();
    
    console.log(`\n--- ${name} Tables & Columns ---`);
    if (!data.definitions) {
      console.log('No definitions found. Make sure PostgREST is exposed.');
      return;
    }
    
    for (const [tableName, definition] of Object.entries(data.definitions)) {
      const parsedTableName = tableName;
      const columns = Object.keys(definition.properties || {});
      console.log(`Table: ${parsedTableName}`);
      columns.forEach(col => {
        const prop = definition.properties[col];
        console.log(`  - ${col} (${prop.type || prop.format})`);
      });
    }
  } catch (error) {
    console.error(`Error fetching schema for ${name}:`, error);
  }
}

async function main() {
  await fetchSchema('Admin DB', env.ADMIN_DB_URL, env.ADMIN_DB_SERVICE_KEY);
  await fetchSchema('Delivery App DB', env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY);
}

main();
