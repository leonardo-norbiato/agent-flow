'use server'

import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export async function login(formData: FormData) {
  const supabase = await createClient()
  const email = formData.get('email') as string
  const password = formData.get('password') as string
  const { error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) redirect('/error')
  redirect('/dashboard')
}

export async function signup(formData: FormData) {
  const supabase = await createClient()
  const email = formData.get('email') as string
  const password = formData.get('password') as string
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || 'http://localhost:3001'
  const { error } = await supabase.auth.signUp({ 
    email, 
    password, 
    options: { 
      emailRedirectTo: `${siteUrl}/verify` 
    } 
  })
  if (error) redirect('/error')
  redirect('/dashboard')
} 