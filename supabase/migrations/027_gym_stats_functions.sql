-- 클라이밍장 전체 통계 (최근 30일)
create or replace function get_gym_stats(p_gym_id uuid)
returns jsonb
language plpgsql
security definer
as $$
declare
  result jsonb;
  cutoff timestamptz := now() - interval '30 days';
begin
  select jsonb_build_object(
    'total_users', (
      select count(distinct user_id)
      from climbing_records
      where gym_id = p_gym_id
        and recorded_at >= cutoff
        and parent_record_id is null
        and deleted_at is null
    ),
    'total_climbs', (
      select count(*)
      from climbing_records
      where gym_id = p_gym_id
        and recorded_at >= cutoff
        and parent_record_id is null
        and deleted_at is null
    ),
    'avg_completion_rate', (
      select coalesce(
        round(
          count(*) filter (where status = 'completed')::numeric
          / nullif(count(*), 0) * 100,
          1
        ),
        0
      )
      from climbing_records
      where gym_id = p_gym_id
        and recorded_at >= cutoff
        and parent_record_id is null
        and deleted_at is null
    ),
    'grade_distribution', (
      select coalesce(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
      from (
        select
          grade,
          count(*) as count,
          round(
            count(*) filter (where status = 'completed')::numeric
            / nullif(count(*), 0) * 100,
            1
          ) as completion_rate
        from climbing_records
        where gym_id = p_gym_id
          and recorded_at >= cutoff
          and parent_record_id is null
          and deleted_at is null
        group by grade
        order by count(*) desc
      ) t
    ),
    'popular_grades', (
      select coalesce(array_agg(grade), '{}')
      from (
        select grade
        from climbing_records
        where gym_id = p_gym_id
          and recorded_at >= cutoff
          and parent_record_id is null
          and deleted_at is null
        group by grade
        order by count(*) desc
        limit 3
      ) t
    )
  ) into result;

  return result;
end;
$$;

-- 내 상대 순위 (최근 30일)
create or replace function get_my_gym_ranking(p_gym_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security definer
as $$
declare
  result jsonb;
  cutoff timestamptz := now() - interval '30 days';
  my_climb_count int;
  my_completed int;
  my_rate numeric;
  my_max_grade text;
  total_users int;
  users_with_more_climbs int;
  users_with_higher_rate int;
  users_with_higher_grade int;
begin
  -- 내 기록 수 & 완등 수
  select count(*), count(*) filter (where status = 'completed')
  into my_climb_count, my_completed
  from climbing_records
  where gym_id = p_gym_id
    and user_id = p_user_id
    and recorded_at >= cutoff
    and parent_record_id is null
    and deleted_at is null;

  my_rate := case when my_climb_count > 0
    then round(my_completed::numeric / my_climb_count * 100, 1)
    else 0 end;

  -- 내 최고 등급 (grade 문자열의 숫자 부분 기준 정렬)
  select grade into my_max_grade
  from climbing_records
  where gym_id = p_gym_id
    and user_id = p_user_id
    and recorded_at >= cutoff
    and parent_record_id is null
    and deleted_at is null
    and status = 'completed'
  order by
    case grade
      when 'vBbbbb' then -4
      when 'vBbb' then -3
      when 'vBb' then -2
      when 'vB' then -1
      when 'v0' then 0
      when 'v1' then 1 when 'v2' then 2 when 'v3' then 3
      when 'v4' then 4 when 'v5' then 5 when 'v6' then 6
      when 'v7' then 7 when 'v8' then 8 when 'v9' then 9
      when 'v10' then 10 when 'v11' then 11 when 'v12' then 12
      when 'v13' then 13 when 'v14' then 14 when 'v15' then 15
      when 'v16' then 16
      else -5
    end desc
  limit 1;

  -- 전체 유저 수 (이 암장, 최근 30일)
  select count(distinct user_id) into total_users
  from climbing_records
  where gym_id = p_gym_id
    and recorded_at >= cutoff
    and parent_record_id is null
    and deleted_at is null;

  -- 나보다 기록 많은 유저 수
  select count(*) into users_with_more_climbs
  from (
    select user_id, count(*) as cnt
    from climbing_records
    where gym_id = p_gym_id
      and recorded_at >= cutoff
      and parent_record_id is null
      and deleted_at is null
    group by user_id
    having count(*) > my_climb_count
  ) t;

  -- 나보다 완등률 높은 유저 수
  select count(*) into users_with_higher_rate
  from (
    select user_id,
      round(count(*) filter (where status = 'completed')::numeric / nullif(count(*), 0) * 100, 1) as rate
    from climbing_records
    where gym_id = p_gym_id
      and recorded_at >= cutoff
      and parent_record_id is null
      and deleted_at is null
    group by user_id
    having round(count(*) filter (where status = 'completed')::numeric / nullif(count(*), 0) * 100, 1) > my_rate
  ) t;

  -- 나보다 높은 등급 완등한 유저 수
  select count(*) into users_with_higher_grade
  from (
    select distinct user_id
    from climbing_records
    where gym_id = p_gym_id
      and recorded_at >= cutoff
      and parent_record_id is null
      and deleted_at is null
      and status = 'completed'
      and case grade
        when 'vBbbbb' then -4 when 'vBbb' then -3 when 'vBb' then -2 when 'vB' then -1
        when 'v0' then 0 when 'v1' then 1 when 'v2' then 2 when 'v3' then 3
        when 'v4' then 4 when 'v5' then 5 when 'v6' then 6 when 'v7' then 7
        when 'v8' then 8 when 'v9' then 9 when 'v10' then 10 when 'v11' then 11
        when 'v12' then 12 when 'v13' then 13 when 'v14' then 14 when 'v15' then 15
        when 'v16' then 16 else -5
      end > coalesce(
        case my_max_grade
          when 'vBbbbb' then -4 when 'vBbb' then -3 when 'vBb' then -2 when 'vB' then -1
          when 'v0' then 0 when 'v1' then 1 when 'v2' then 2 when 'v3' then 3
          when 'v4' then 4 when 'v5' then 5 when 'v6' then 6 when 'v7' then 7
          when 'v8' then 8 when 'v9' then 9 when 'v10' then 10 when 'v11' then 11
          when 'v12' then 12 when 'v13' then 13 when 'v14' then 14 when 'v15' then 15
          when 'v16' then 16 else -5
        end, -5)
  ) t;

  result := jsonb_build_object(
    'my_climbs', my_climb_count,
    'my_completion_rate', my_rate,
    'climbs_percentile', case when total_users > 0
      then ceil((users_with_more_climbs + 1)::numeric / total_users * 100)
      else 0 end,
    'completion_percentile', case when total_users > 0
      then ceil((users_with_higher_rate + 1)::numeric / total_users * 100)
      else 0 end,
    'highest_grade', coalesce(my_max_grade, ''),
    'grade_percentile', case when total_users > 0
      then ceil((users_with_higher_grade + 1)::numeric / total_users * 100)
      else 0 end
  );

  return result;
end;
$$;
