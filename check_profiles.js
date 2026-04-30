import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
dotenv.config();

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

async function checkTable() {
  const { data, error } = await supabase.from('delivery_profiles').select('*').limit(1);
  if (error) {
    console.error('Error fetching table:', error.message);
  } else {
    console.log('Sample row from delivery_profiles:');
    console.log(JSON.stringify(data, null, 2));
  }
}

checkTable();
