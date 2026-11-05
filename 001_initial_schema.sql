-- Initial schema for Archive Document Portal
-- Review and test all RLS policies before production.

create extension if not exists pgcrypto;

create type public.app_role as enum ('system_admin', 'branch_manager', 'central_archive');
create type public.report_status as enum ('draft', 'submitted', 'under_review', 'returned', 'approved');
create type public.entry_mode as enum ('number_range', 'date_range');
create type public.approval_action as enum ('submit_attestation', 'final_approval', 'returned_for_changes');

create table public.branches (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  code text unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  employee_number text not null unique,
  full_name text not null,
  role public.app_role not null default 'branch_manager',
  branch_id uuid references public.branches(id),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint branch_manager_requires_branch check (role <> 'branch_manager' or branch_id is not null)
);

create table public.document_types (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

insert into public.document_types(name, sort_order) values
('سندات صرف عام', 1),
('سندات صرف حوالة', 2),
('سندات صرف عملاء', 3),
('ملفات فتح الحسابات', 4),
('تقارير الجرد', 5),
('تعديل / تغيير رقم الجوال', 6),
('إشعارات البنوك', 7);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reference_no text unique,
  branch_id uuid not null references public.branches(id),
  created_by uuid not null references public.profiles(id),
  status public.report_status not null default 'draft',
  report_date date not null default current_date,
  general_notes text,
  submitted_at timestamptz,
  submitter_name_snapshot text,
  submitter_employee_no_snapshot text,
  submitter_branch_snapshot text,
  final_approved_at timestamptz,
  final_approved_by uuid references public.profiles(id),
  final_approver_name_snapshot text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.report_items (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete cascade,
  document_type_id uuid not null references public.document_types(id),
  entry_mode public.entry_mode not null,
  number_from text,
  number_to text,
  date_from date,
  date_to date,
  document_count integer check (document_count is null or document_count >= 0),
  archive_status text,
  arrangement_status text,
  notes text,
  created_at timestamptz not null default now(),
  constraint valid_item_range check (
    (entry_mode = 'number_range' and number_from is not null and number_to is not null and date_from is null and date_to is null)
    or
    (entry_mode = 'date_range' and date_from is not null and date_to is not null and number_from is null and number_to is null)
  )
);

create table public.handover_receipts (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null unique references public.reports(id) on delete cascade,
  handover_date date not null default current_date,
  sender_profile_id uuid not null references public.profiles(id),
  receiver_name text,
  receiver_employee_no text,
  sender_acknowledged_at timestamptz,
  receiver_acknowledged_at timestamptz,
  sender_signature_text text,
  receiver_signature_text text,
  notes text,
  paper_copy_optional boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.attachments (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete cascade,
  storage_path text not null,
  file_name text not null,
  mime_type text,
  uploaded_by uuid not null references public.profiles(id),
  is_optional_paper_copy boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.report_approvals (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete cascade,
  actor_id uuid not null references public.profiles(id),
  action public.approval_action not null,
  actor_name_snapshot text not null,
  actor_employee_no_snapshot text not null,
  actor_role_snapshot public.app_role not null,
  notes text,
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  report_id uuid references public.reports(id) on delete set null,
  actor_id uuid references public.profiles(id),
  action text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index reports_branch_date_idx on public.reports(branch_id, report_date desc);
create index reports_status_idx on public.reports(status);
create index report_items_type_idx on public.report_items(document_type_id);
create index approvals_report_idx on public.report_approvals(report_id, created_at);

-- Helper functions. SECURITY DEFINER functions must be reviewed carefully.
create or replace function public.current_app_role()
returns public.app_role
language sql stable security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid() and is_active = true
$$;

create or replace function public.current_branch_id()
returns uuid
language sql stable security definer
set search_path = public
as $$
  select branch_id from public.profiles where id = auth.uid() and is_active = true
$$;

alter table public.branches enable row level security;
alter table public.profiles enable row level security;
alter table public.document_types enable row level security;
alter table public.reports enable row level security;
alter table public.report_items enable row level security;
alter table public.handover_receipts enable row level security;
alter table public.attachments enable row level security;
alter table public.report_approvals enable row level security;
alter table public.audit_logs enable row level security;

-- Read policies: admins/archive staff see all; branch managers see their own branch.
create policy "branches readable by authenticated users" on public.branches
for select to authenticated using (
  public.current_app_role() in ('system_admin','central_archive') or id = public.current_branch_id()
);
create policy "profiles readable by privileged users or self" on public.profiles
for select to authenticated using (
  id = auth.uid() or public.current_app_role() in ('system_admin','central_archive')
);
create policy "document types active readable" on public.document_types
for select to authenticated using (
  is_active = true or public.current_app_role() = 'system_admin'
);
create policy "reports visible by scope" on public.reports
for select to authenticated using (
  public.current_app_role() in ('system_admin','central_archive') or branch_id = public.current_branch_id()
);
create policy "report items visible by report scope" on public.report_items
for select to authenticated using (
  exists(select 1 from public.reports r where r.id = report_id and
    (public.current_app_role() in ('system_admin','central_archive') or r.branch_id = public.current_branch_id()))
);
create policy "receipts visible by report scope" on public.handover_receipts
for select to authenticated using (
  exists(select 1 from public.reports r where r.id = report_id and
    (public.current_app_role() in ('system_admin','central_archive') or r.branch_id = public.current_branch_id()))
);
create policy "attachments visible by report scope" on public.attachments
for select to authenticated using (
  exists(select 1 from public.reports r where r.id = report_id and
    (public.current_app_role() in ('system_admin','central_archive') or r.branch_id = public.current_branch_id()))
);
create policy "approvals visible by report scope" on public.report_approvals
for select to authenticated using (
  exists(select 1 from public.reports r where r.id = report_id and
    (public.current_app_role() in ('system_admin','central_archive') or r.branch_id = public.current_branch_id()))
);
create policy "audit visible by privileged users" on public.audit_logs
for select to authenticated using (public.current_app_role() in ('system_admin','central_archive'));

-- Writes are intentionally restricted in this starter. Implement secure RPCs/Edge Functions
-- for submit_report, return_report, and final_approve_report, then add narrowly-scoped policies.
-- Do not add broad authenticated INSERT/UPDATE policies: submission must snapshot identity,
-- create submit_attestation, assign reference_no, and atomically change status.
