-- =====================================================================================
-- NOTIFY ADMIN WHEN USER SENDS SUPPORT REQUEST
-- =====================================================================================
-- This migration modifies send_message to automatically notify admin via WhatsApp
-- when a non-admin user sends a message in a support conversation
-- =====================================================================================

begin;

-- Ensure pg_net extension is enabled (required for HTTP requests to edge functions)
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Modify send_message function to notify admin when user sends support request
create or replace function public.send_message(
  p_conversation_id uuid,
  p_body text default null,
  p_kind text default 'text',
  p_order_id uuid default null,
  p_reply_to uuid default null,
  p_sender_id uuid default null,
  p_attachment_url text default null,
  p_attachment_type text default null
) returns public.messages
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_message public.messages%rowtype;
  v_sender uuid;
  v_sender_role text;
  v_recipient_id uuid;
  v_sender_name text;
  v_message_preview text;
  v_placeholder_phone text := '9990000001';
  v_conversation_is_support boolean;
  v_sender_phone text;
  v_supabase_url text;
  v_service_role_key text;
begin
  v_sender := coalesce(p_sender_id, auth.uid());
  if v_sender is null then
    raise exception 'UNAUTHENTICATED_SENDER';
  end if;

  -- Ensure sender exists in users table
  insert into public.users(id, name, role, phone, is_online, created_at)
  values (v_sender, 'مستخدم', 'admin', v_placeholder_phone, true, now())
  on conflict (id) do update
    set phone = coalesce(public.users.phone, excluded.phone),
        name  = coalesce(public.users.name, excluded.name),
        role  = coalesce(public.users.role, excluded.role),
        updated_at = now();

  -- Get sender's role, name, and phone
  select role, name, phone into v_sender_role, v_sender_name, v_sender_phone
  from public.users
  where id = v_sender;

  -- Check if conversation is a support conversation
  select is_support into v_conversation_is_support
  from public.conversations
  where id = p_conversation_id;

  -- Insert the message
  insert into public.messages(
    conversation_id,
    sender_id,
    body,
    kind,
    order_id,
    reply_to_message_id,
    attachment_url,
    attachment_type
  )
  values (
    p_conversation_id,
    v_sender,
    coalesce(p_body, ''),
    coalesce(p_kind, 'text'),
    p_order_id,
    p_reply_to,
    p_attachment_url,
    p_attachment_type
  )
  returning * into v_message;

  -- If sender is a driver, notify the other participants
  if v_sender_role = 'driver' then
    -- Get message preview (first 100 chars or indicate attachment)
    if p_attachment_url is not null then
      v_message_preview := case p_attachment_type
        when 'image' then 'صورة / Image'
        when 'file' then 'ملف / File'
        else 'مرفق / Attachment'
      end;
    else
      v_message_preview := coalesce(substring(p_body from 1 for 100), 'رسالة جديدة / New message');
    end if;

    -- Find all other participants in the conversation (excluding the sender)
    for v_recipient_id in
      select cp.user_id
      from conversation_participants cp
      where cp.conversation_id = p_conversation_id
        and cp.user_id != v_sender
    loop
      -- Create notification for each recipient
      insert into public.notifications(
        user_id,
        type,
        title,
        body,
        data
      )
      values (
        v_recipient_id,
        'message',
        coalesce(v_sender_name, 'سائق / Driver'),
        v_message_preview,
        jsonb_build_object(
          'conversation_id', p_conversation_id::text,
          'message_id', v_message.id::text,
          'sender_id', v_sender::text,
          'sender_name', coalesce(v_sender_name, 'سائق / Driver'),
          'order_id', coalesce(p_order_id::text, '')
        )
      );
    end loop;
  end if;

  -- If this is a support conversation and sender is not an admin, notify admin via WhatsApp
  if coalesce(v_conversation_is_support, false) and v_sender_role != 'admin' then
    begin
      -- Check if pg_net extension is available
      if not exists (select 1 from pg_extension where extname = 'pg_net') then
        raise warning 'pg_net extension not found. Cannot send support notification. Install with: CREATE EXTENSION IF NOT EXISTS pg_net;';
      else
        -- Try to get Supabase URL and service role key using helper functions
        -- These read from system_settings table (no superuser required)
        -- Configure via: INSERT/UPDATE system_settings table (see configure_support_notification.sql)
        declare
          v_project_ref text;
        begin
          -- Get project ref and service key using existing helper functions
          -- These functions check system_settings table first, then fallback to database settings
          select get_supabase_project_ref() into v_project_ref;
          select get_service_role_key() into v_service_role_key;
          
          -- Construct full URL from project ref
          if v_project_ref is not null and v_project_ref != '' and v_project_ref != 'YOUR_PROJECT_REF' then
            v_supabase_url := format('https://%s.supabase.co', v_project_ref);
          end if;

          -- Only proceed if we have both URL and key configured
          if v_supabase_url is not null and v_service_role_key is not null 
             and v_service_role_key != '' and v_service_role_key != 'YOUR_SERVICE_ROLE_KEY' then
        -- Get message preview for admin notification
        if p_attachment_url is not null then
          v_message_preview := case p_attachment_type
            when 'image' then 'صورة / Image'
            when 'file' then 'ملف / File'
            else 'مرفق / Attachment'
          end;
        else
          v_message_preview := coalesce(p_body, '');
        end if;

        -- Call the edge function to notify admin via WhatsApp
        -- This is non-blocking - if it fails, we log but don't fail the message sending
        perform net.http_post(
          url := v_supabase_url || '/functions/v1/wasso-send-support-notification',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || v_service_role_key
          ),
          body := jsonb_build_object(
            'conversation_id', p_conversation_id::text,
            'message_id', v_message.id::text,
            'sender_id', v_sender::text,
            'message_body', v_message_preview,
            'sender_name', coalesce(v_sender_name, 'مستخدم'),
            'sender_role', coalesce(v_sender_role, 'user'),
            'sender_phone', coalesce(v_sender_phone, 'غير متوفر')
          )
        );

          raise notice 'Support request notification sent to admin for conversation %', p_conversation_id;
        else
          -- Log that configuration is missing but don't fail
            raise warning 'Skipping admin notification: Supabase URL or service role key not configured. Set in system_settings table (see configure_support_notification.sql)';
          end if;
        end;
      end if;
    exception when others then
      -- Log the error but don't fail the message sending
      raise warning 'Failed to send admin notification for support request: %', sqlerrm;
    end;
  end if;

  return v_message;
end;
$$;

grant execute on function public.send_message(uuid, text, text, uuid, uuid, uuid, text, text) to authenticated;
grant execute on function public.send_message(uuid, text, text, uuid, uuid, uuid, text, text) to anon;

comment on function public.send_message(uuid, text, text, uuid, uuid, uuid, text, text) is 
  'Sends a message in a conversation. Notifies admin via WhatsApp when non-admin users send support requests.';

commit;

