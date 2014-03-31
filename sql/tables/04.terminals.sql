create sequence terminals.seq_models;
create table terminals.models(
  id bigint,
  title varchar,
  protocols terminals.protocols[],

  constraint zidx_models_pk primary key(id),
  constraint zidx_models_uk_title unique(title)
);

create trigger insertb_00_set_id
  before insert
  on terminals.models
  for each row
  when (new.id is null)
  execute procedure triggers.set_id();

create sequence terminals.seq_data;
create table terminals.data(
  id bigint,
  uin bigint not null,
  serial_no varchar not null,
  period interval not null default '00:03:00',
  model_id bigint not null,
  owner_id bigint,

  constraint zidx_terminals_pk primary key(id),
  constraint zidx_terminals_uk_uin_model unique(uin, model_id),
  constraint zidx_terminals_uk_serial_model unique(serial_no, model_id),
  constraint zidx_terminals_fk_model foreign key(model_id) references terminals.models(id),
  constraint zidx_terminals_fk_owner foreign key(owner_id) references owners.data(id)
);

create trigger insertb_00_set_id
  before insert
  on terminals.data
  for each row
  when (new.id is null)
  execute procedure triggers.set_id();

create sequence terminals.seq_commands;
create table terminals.commands(
  id bigint,
  dbtime timestamptz not null default current_timestamp,
  terminal_id bigint
    not null
    constraint zidx_commands_fk_terminal references terminals.data(id),
  command bytea not null,
  type terminals.command_send_type not null default 'answer',
  executed timestamptz,

  constraint zidx_commands_pk primary key(id)
);

create trigger insertb_00_set_id
  before insert
  on terminals.commands
  for each row
  when (new.id is null)
  execute procedure triggers.set_id();
