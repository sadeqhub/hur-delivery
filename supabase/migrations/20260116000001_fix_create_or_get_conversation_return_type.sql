-- =====================================================================================
-- FIX CREATE_OR_GET_CONVERSATION RETURN TYPE
-- =====================================================================================
-- This migration ensures create_or_get_conversation returns properly formatted
-- values that work with Supabase Flutter SDK's PostgrestResponse handling
-- =====================================================================================

begin;

-- Ensure create_or_get_conversation function returns UUID correctly
-- The function should return a UUID value that Supabase wraps in PostgrestResponse
create or replace function public.create_or_get_conversation(
  p_order_id uuid,
  p_participant_ids uuid[],
  p_is_support boolean default false
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_conversation_id uuid;
begin
  -- Check for existing conversation by order_id
  if p_order_id is not null then
    select id into v_conversation_id
    from public.conversations
    where order_id = p_order_id and is_support = coalesce(p_is_support,false)
    limit 1;
  else
    -- For support conversations without order_id, reuse existing if available
    if coalesce(p_is_support,false) then
      select id into v_conversation_id
      from public.conversations
      where is_support = true
        and created_by = auth.uid()
        and (is_archived is null or is_archived = false)
      order by created_at desc
      limit 1;
    end if;
  end if;

  -- Create new conversation if it doesn't exist
  if v_conversation_id is null then
    insert into public.conversations(order_id, created_by, is_support)
    values (p_order_id, auth.uid(), coalesce(p_is_support,false))
    returning id into v_conversation_id;
    
    -- add creator + provided participants
    insert into public.conversation_participants(conversation_id, user_id, role)
    values (v_conversation_id, auth.uid(), 'member')
    on conflict do nothing;

    if p_participant_ids is not null and array_length(p_participant_ids, 1) > 0 then
      insert into public.conversation_participants(conversation_id, user_id, role)
      select v_conversation_id, unnest(p_participant_ids), 'member'
      on conflict do nothing;
    end if;
  end if;

  -- Ensure we always return a valid UUID
  if v_conversation_id is null then
    raise exception 'Failed to create or get conversation';
  end if;

  return v_conversation_id;
end;
$$;

grant execute on function public.create_or_get_conversation(uuid, uuid[], boolean) to authenticated;
grant execute on function public.create_or_get_conversation(uuid, uuid[], boolean) to anon;

comment on function public.create_or_get_conversation(uuid, uuid[], boolean) is 
  'Creates or retrieves a conversation. For support conversations, reuses existing non-archived conversation if available. Returns conversation UUID.';

commit;















