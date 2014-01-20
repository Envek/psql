create sequence replica.seq_m2m;
create table replica.m2m(
  id bigint,
  type data.types not null,
  terminal_id bigint not null,
  eventtime timestamp with time zone not null,
  latitude navigation.coords_gm not null,
  longitude navigation.coords_gm not null,
  used bigint not null default 0,
  speed bigint not null default 0,
  course bigint not null default 0,
  track real not null default 0,
  action bigint not null default 0,
  reboot bigint not null default 0,

  constraint zidx_m2m_pk primary key(id),
  constraint zudx_m2m_fk_id foreign key (id) references data.packets(id) on delete cascade,
  constraint zidx_m2m_fk_terminal foreign key (terminal_id) references terminals.data(id) on delete cascade
);

create trigger insertb_00_set_id
  before insert on replica.m2m
  for each row
  when (new.id is null)
  execute procedure triggers.set_id();

create function replica.m2m(
  _type data.types,
  _terminal_id bigint,
  _eventtime timestamp with time zone,
  _latitude navigation.coords_gm,
  _longitude navigation.coords_gm,
  _used bigint,
  _speed bigint,
  _course bigint) returns table (
    track bigint,
    action bigint,
    reboot bigint
  ) as $$
declare
  prev record;
  next record;
  tr real;
  act bigint;
  re bigint;
  diff real;
  et timestamp with time zone;
begin
  tr = 0;
  act = x'20'::bigint;
  re = 1;
  diff = 0;

  select * into prev
  from replica.m2m T
  where t.terminal_id=_terminal_id and t.eventtime<=_eventtime
  order by t.eventtime desc
  limit 1;
  select * into next
  from replica.m2m T
  where t.terminal_id=_terminal_id and t.eventtime>_eventtime
  order by t.eventtime
  limit 1;

  raise notice 'checking for terminal %, eventtime is %', _terminal_id, _eventtime;
  if prev is not null then
    if prev.eventtime = _eventtime then
      tr = prev.track;
      act = prev.action;
      re = prev.reboot;
    else
      if _used>3 and prev.used>3 then
        diff = navigation.distance(_latitude, _longitude, prev.latitude, prev.longitude);
      else
        diff = 0;
      end if;

      if (_eventtime - prev.eventtime) <= interval '1:0:0' then
        re = 0;
      elsif _type = 'offline' then
        re = 1;
      elsif diff<100 then
        re = 1;
      else
        re = 0;
      end if;

      if re=0 and prev.eventtime <> _eventtime then
        tr = diff + prev.track;
        if _speed = 0 then
          if prev.speed = 0 then
            act = x'20'::bigint;
          else
            act = x'60'::bigint;
          end if;
        elsif abs(_course - prev.course) > 100 then
          act = x'4'::bigint;
        else
          act = x'1'::bigint;
        end if;
      end if;
    end if;
  end if;

  if re=0 and next is not null and next.reboot=0 then
    select eventtime into et from replica.m2m t
    where t.terminal_id=_terminal_id and t.eventtime>_eventtime and t.reboot = 1
    order by eventtime
    limit 1;

    if _used > 3 and next.used > 3 then
      diff = navigation.distance(_latitude,_longitude, next.latitude, next.longitude);
    else
      diff = 0;
    end if;
    if prev is not null then
      diff = navigation.distance(_latitude, _longitude, prev.latitude, prev.longitude)
      + diff - (next.track - prev.track);
    end if;
    if et is null and diff<>0 then
      update replica.m2m t set track=t.track+diff
      where t.terminal_id=_terminal_id and t.eventtime>_eventtime;
    else
      update replica.m2m t set track=t.track+diff
      where t.terminal_id=_terminal_id and t.eventtime>_eventtime and t.eventtime<et;
    end if;
  end if;
  
  raise notice 'returning track: %, action: %, reboot: %', tr, act, re;
  return query select floor(tr / 100)::bigint,act::bigint,re::bigint;

  delete from replica.m2m t
  where t.terminal_id=_terminal_id and t.type = _type and t.eventtime<=_eventtime;

  insert into replica.m2m
  values (null, _type, _terminal_id,
    _eventtime, _latitude, _longitude, 
    _used, _speed, _course,
    tr, act, re);
end $$ language plpgsql;
