-- =====================================================================================
-- SUPPORT AGENT TRIGGER
-- =====================================================================================
-- Fires after any non-admin message is inserted into a support conversation.
-- Calls the support-agent edge function (non-blocking via pg_net) which runs
-- an OpenAI agentic loop and posts an AI reply back to the conversation.
--
-- Anti-loop guarantee: the agent posts replies as the admin user.
-- The trigger skips rows where sender role = 'admin', so agent replies
-- never re-trigger the function.
-- =====================================================================================

begin;

create extension if not exists pg_net with schema extensions;

-- ─── Trigger function ─────────────────────────────────────────────────────────

create or replace function public.trigger_support_agent()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_is_support      boolean;
  v_sender_role     text;
  v_sender_name     text;
  v_project_ref     text;
  v_service_key     text;
  v_supabase_url    text;
  v_message_body    text;
begin
  -- Only process text messages (skip system events, attachments handled below)
  -- We still want to handle attachment messages so the agent knows context
  -- but we only trigger when there is a body or a known kind.
  if NEW.kind not in ('text', 'image', 'file', 'voice') then
    return NEW;
  end if;

  -- Check if the conversation is a support conversation
  select is_support
    into v_is_support
    from public.conversations
   where id = NEW.conversation_id;

  if not coalesce(v_is_support, false) then
    return NEW;
  end if;

  -- Get sender's role and name
  select role, name
    into v_sender_role, v_sender_name
    from public.users
   where id = NEW.sender_id;

  -- Do NOT trigger for admin messages — prevents infinite loops
  if coalesce(v_sender_role, 'user') = 'admin' then
    return NEW;
  end if;

  -- Build message body preview for the agent
  v_message_body := case NEW.kind
    when 'image' then '[صورة / Image attachment]'
    when 'file'  then '[ملف / File attachment]'
    when 'voice' then '[رسالة صوتية / Voice message]'
    else coalesce(NEW.body, '')
  end;

  -- Retrieve project ref and service role key from system_settings
  -- (configured via configure_support_notification.sql)
  begin
    select get_supabase_project_ref() into v_project_ref;
    select get_service_role_key()     into v_service_key;
  exception when others then
    raise warning 'support_agent_trigger: could not retrieve config — %', sqlerrm;
    return NEW;
  end;

  if v_project_ref is null or v_project_ref = '' or v_project_ref = 'YOUR_PROJECT_REF' then
    raise warning 'support_agent_trigger: SUPABASE project ref not configured';
    return NEW;
  end if;

  if v_service_key is null or v_service_key = '' or v_service_key = 'YOUR_SERVICE_ROLE_KEY' then
    raise warning 'support_agent_trigger: service role key not configured';
    return NEW;
  end if;

  v_supabase_url := format('https://%s.supabase.co', v_project_ref);

  -- Fire-and-forget HTTP call to the support-agent edge function
  perform net.http_post(
    url     := v_supabase_url || '/functions/v1/support-agent',
    headers := jsonb_build_object(
      'Content-Type',   'application/json',
      'Authorization',  'Bearer ' || v_service_key
    ),
    body    := jsonb_build_object(
      'conversation_id', NEW.conversation_id::text,
      'message_id',      NEW.id::text,
      'sender_id',       NEW.sender_id::text,
      'message_body',    v_message_body,
      'sender_name',     coalesce(v_sender_name, 'مستخدم'),
      'sender_role',     coalesce(v_sender_role, 'user')
    )
  );

  return NEW;

exception when others then
  -- Never fail the original message insert
  raise warning 'support_agent_trigger: unexpected error — %', sqlerrm;
  return NEW;
end;
$$;

-- ─── Drop old trigger if it exists, then create fresh ─────────────────────────

drop trigger if exists ai_support_agent_trigger on public.messages;

create trigger ai_support_agent_trigger
  after insert on public.messages
  for each row
  execute function public.trigger_support_agent();

comment on function public.trigger_support_agent() is
  'Calls the support-agent edge function after a non-admin message is inserted in a support conversation.';

commit;
