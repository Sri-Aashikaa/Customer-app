import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.EXPO_PUBLIC_SUPABASE_URL || 'https://eftixvhkmtujlbayrauk.supabase.co';
const SUPABASE_ANON_KEY = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVmdGl4dmhrbXR1amxiYXlyYXVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ0NzcyNjgsImV4cCI6MjExMDA1MzI2OH0.NWAHkzFcAS9w9YF_v7-_GVRa_c5Rb4Ltkc3BUweXNrg';

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('[SECURITY CONFIG ERROR] Supabase credentials missing. Check your .env file.');
}

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: false,
  },
});
