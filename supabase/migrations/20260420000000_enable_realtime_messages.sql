-- =====================================================================================
-- ENABLE REALTIME ON MESSAGES TABLE
-- =====================================================================================
-- The Flutter app subscribes to INSERTs on public.messages to deliver chat replies
-- (including AI support agent responses) in real-time. Without the table being in the
-- supabase_realtime publication, subscribers only receive the initial fetch and never
-- see new rows until they re-open the screen.
-- =====================================================================================

begin;

-- Add messages to the realtime publication. Wrapped to be idempotent.
do $$
begin
  alter publication supabase_realtime add table public.messages;
exception
  when duplicate_object then
    -- Already in publication — nothing to do.
    null;
end $$;

-- REPLICA IDENTITY FULL ensures the realtime payload includes all columns
-- (needed so the client can read sender_id, body, conversation_id, etc.)
alter table public.messages replica identity full;

commit;
