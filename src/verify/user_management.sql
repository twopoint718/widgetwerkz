-- Verify widgetwerkz:user_management on pg

BEGIN;

select pg_catalog.has_schema_privilege('basic_auth', 'usage');
select has_function_privilege('basic_auth.check_role_exists()', 'execute');
select has_function_privilege('basic_auth.user_role(text, text)', 'execute');
select has_function_privilege('basic_auth.encrypt_pass()', 'execute');
select has_function_privilege('login(text, text)', 'execute');
select pg_catalog.has_table_privilege('basic_auth.users', 'select');
select 1/count(tgname) from pg_catalog.pg_trigger where tgname = 'ensure_user_role_exists';
select 1/count(tgname) from pg_catalog.pg_trigger where tgname = 'encrypt_pass';

ROLLBACK;