import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.EXPO_PUBLIC_SUPABASE_URL || 'https://czmnxrrqcrcqwvdlruif.supabase.co';
const SUPABASE_ANON_KEY = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN6bW54cnJxY3JjcXd2ZGxydWlmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMTU5NjAsImV4cCI6MjEwNTg5MTk2MH0.-jex033UIYC_PnoLg53pWeKZVY68gIsJFWJiDzO7if0';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
