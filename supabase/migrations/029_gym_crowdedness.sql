-- 암장 실시간 포화도 (최근 1시간 활동 유저 수)
create or replace function get_gym_crowdedness(p_gym_id uuid)
returns jsonb
language plpgsql
security definer
as $$
declare
  result jsonb;
  cutoff timestamptz := now() - interval '1 hour';
begin
  select jsonb_build_object(
    'active_users', (
      select count(distinct user_id)
      from climbing_records
      where gym_id = p_gym_id
        and created_at >= cutoff
        and parent_record_id is null
        and deleted_at is null
    )
  ) into result;

  return result;
end;
$$;
