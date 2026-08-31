-- ============================================================================
-- Bastion v2 — 02_seed.sql   (demo2 · schema: bastion_v2)
-- Same auth users as v1 (users are per-project) — no user creation needed.
-- Idempotent: safe to re-run.
-- ============================================================================

do $$ declare v int;
begin
  select count(*) into v from auth.users
  where email in ('ada@apex.test','sam@meridian.test');
  if v <> 2 then
    raise exception 'Expected both demo users, found %. Create them first, then re-run.', v;
  end if;
end $$;

insert into bastion_v2.organizations (slug, name) values
  ('apex',     'Apex Financial'),
  ('meridian', 'Meridian Health')
on conflict (slug) do nothing;

insert into bastion_v2.departments (org_id, slug, name)
select o.id, v.slug, v.name
from (values
  ('apex',     'payments', 'Payments & Transfers'),
  ('apex',     'platform', 'Platform Engineering'),
  ('apex',     'identity', 'Identity & Access'),
  ('apex',     'corp-it',  'Corporate IT'),
  ('meridian', 'clinical', 'Clinical Systems'),
  ('meridian', 'data',     'Data & Analytics'),
  ('meridian', 'corp-it',  'Corporate IT')
) as v(org_slug, slug, name)
join bastion_v2.organizations o on o.slug = v.org_slug
on conflict (org_id, slug) do nothing;

insert into bastion_v2.projects (org_id, department_id, slug, name)
select o.id, d.id, v.slug, v.name
from (values
  ('apex','payments','checkout-api',       'Checkout API'),
  ('apex','payments','webhook-service',    'Webhook Service'),
  ('apex','payments','transfer-service',   'Transfer Service'),
  ('apex','platform','statements-storage', 'Statements Storage'),
  ('apex','platform','api-gateway',        'API Gateway'),
  ('apex','platform','k8s-fleet',          'Kubernetes Fleet'),
  ('apex','identity','admin-console',      'Admin Console'),
  ('apex','identity','auth-service',       'Auth Service'),
  ('apex','corp-it', 'marketing-site',     'Marketing Site'),
  ('apex','corp-it', 'dns-infra',          'DNS Infrastructure'),
  ('apex','corp-it', 'legacy-portal',      'Legacy Transfer Portal'),
  ('meridian','clinical','patient-portal',     'Patient Portal'),
  ('meridian','clinical','fhir-api',           'FHIR API'),
  ('meridian','clinical','appointment-api',    'Appointment API'),
  ('meridian','clinical','device-gateway',     'Device Gateway'),
  ('meridian','data',    'intake-archive',     'Intake Archive'),
  ('meridian','data',    'analytics-warehouse','Analytics Warehouse'),
  ('meridian','corp-it', 'integration-api',    'Integration API'),
  ('meridian','corp-it', 'legacy-portal',      'Legacy Portal')
) as v(org_slug, dept_slug, slug, name)
join bastion_v2.organizations o on o.slug = v.org_slug
join bastion_v2.departments d on d.org_id = o.id and d.slug = v.dept_slug
on conflict (org_id, slug) do nothing;

insert into bastion_v2.teams (org_id, project_id, slug, name)
select o.id, p.id, v.slug, v.name
from (values
  ('apex','checkout-api','payments-gateway','Payments Gateway'),
  ('apex','checkout-api','checkout-web',    'Checkout Web'),
  ('apex','webhook-service','webhooks',     'Webhooks'),
  ('apex','transfer-service','transfers',   'Transfers'),
  ('apex','statements-storage','storage-infra','Storage Infrastructure'),
  ('apex','api-gateway','edge-platform',    'Edge Platform'),
  ('apex','k8s-fleet','platform-sre',       'Platform SRE'),
  ('apex','admin-console','iam',            'IAM'),
  ('apex','auth-service','identity-eng',    'Identity Engineering'),
  ('apex','marketing-site','web-presence',  'Web Presence'),
  ('apex','dns-infra','netops',             'Network Operations'),
  ('apex','legacy-portal','legacy-apps',    'Legacy Applications'),
  ('meridian','patient-portal','portal-eng',      'Portal Engineering'),
  ('meridian','fhir-api','fhir-eng',              'FHIR Engineering'),
  ('meridian','appointment-api','scheduling-eng', 'Scheduling Engineering'),
  ('meridian','device-gateway','device-eng',      'Device Engineering'),
  ('meridian','intake-archive','data-platform',   'Data Platform'),
  ('meridian','analytics-warehouse','analytics-eng','Analytics Engineering'),
  ('meridian','integration-api','integrations',   'Integrations'),
  ('meridian','legacy-portal','legacy-maint',     'Legacy Maintenance')
) as v(org_slug, project_slug, slug, name)
join bastion_v2.organizations o on o.slug = v.org_slug
join bastion_v2.projects p on p.org_id = o.id and p.slug = v.project_slug
on conflict (org_id, slug) do nothing;

insert into bastion_v2.members (org_id, user_id, role)
select o.id, u.id, 'admin'
from bastion_v2.organizations o
join auth.users u on u.email = 'ada@apex.test'
where o.slug = 'apex'
on conflict do nothing;

insert into bastion_v2.members (org_id, user_id, role)
select o.id, u.id, 'admin'
from bastion_v2.organizations o
join auth.users u on u.email = 'sam@meridian.test'
where o.slug = 'meridian'
on conflict do nothing;

insert into bastion_v2.team_members (team_id, org_id, user_id, role)
select t.id, t.org_id, u.id, v.role
from (values
  ('apex','payments-gateway','ada@apex.test','admin'),
  ('apex','storage-infra',   'ada@apex.test','viewer'),
  ('meridian','portal-eng',  'sam@meridian.test','admin'),
  ('meridian','data-platform','sam@meridian.test','viewer')
) as v(org_slug, team_slug, email, role)
join bastion_v2.organizations o on o.slug = v.org_slug
join bastion_v2.teams t on t.org_id = o.id and t.slug = v.team_slug
join auth.users u on u.email = v.email
on conflict do nothing;

insert into bastion_v2.root_causes
      (code, title, severity, first_discovered, fix_available, fix_method, fix_effort, workaround)
values
  ('CWE-89',        'SQL Injection',                              'critical', '2002-01-01', true,  'code_change',          'high',   'WAF virtual patch while parameterization lands'),
  ('CWE-347',       'Improper JWT signature verification',         'critical', '2015-01-01', true,  'code_change',          'high',   'Reject unsigned algorithms at the gateway'),
  ('CWE-798',       'Hardcoded or embedded credentials',           'critical', '2002-01-01', true,  'credential_rotation',  'medium', 'Rotate exposed secrets; block at egress'),
  ('CWE-732',       'Incorrect resource permissions',              'critical', '2010-01-01', true,  'configuration_change','low',    'Restrict bucket policy to authenticated roles'),
  ('CWE-285',       'Broken access control (object-level)',        'critical', '2005-01-01', true,  'code_change',          'high',   'Enforce object-level authorization middleware'),
  ('CVE-2021-44228','Log4Shell',                                   'critical', '2021-12-10', true,  'version_upgrade',      'low',    'Upgrade Log4j to 2.17+'),
  ('CWE-639',       'IDOR on object references',                   'high',     '2014-01-01', true,  'code_change',          'high',   'Authorize object ownership per request'),
  ('CWE-918',       'Server-Side Request Forgery',                 'high',     '2015-01-01', true,  'code_change',          'high',   'Allowlist outbound destinations'),
  ('CWE-326',       'Inadequate encryption strength (weak TLS)',   'high',     '2008-01-01', true,  'configuration_change','low',    'Disable TLS 1.0/1.1 and CBC suites'),
  ('CWE-362',       'Race condition',                              'high',     '2012-01-01', false, 'code_change',          'high',   'Idempotency keys on confirmation'),
  ('CWE-311',       'Missing encryption of sensitive data',        'high',     '2008-01-01', true,  'configuration_change','high',   'Encrypt PHI columns at rest'),
  ('CWE-434',       'Unrestricted file upload',                    'high',     '2010-01-01', true,  'code_change',          'medium', 'Validate type; store outside web root'),
  ('CWE-384',       'Session fixation',                            'high',     '2008-01-01', true,  'code_change',          'medium', 'Rotate session id on login'),
  ('CWE-770',       'Missing rate limiting',                       'medium',   '2010-01-01', true,  'configuration_change','medium', 'Edge rate-limit rules per route'),
  ('CVE-2020-11022','jQuery XSS (CVE-2020-11022)',                 'medium',   '2020-04-30', true,  'version_upgrade',      'low',    'Upgrade jQuery to 3.5+'),
  ('CWE-209',       'Verbose error responses',                     'medium',   '2007-01-01', true,  'configuration_change','low',    'Disable stack traces in production'),
  ('CWE-1021',      'Clickjacking (missing frame protections)',    'medium',   '2010-01-01', true,  'configuration_change','low',    'Send CSP frame-ancestors / X-Frame-Options'),
  ('CWE-324',       'Expired or unvalidated certificate',          'medium',   '2012-01-01', true,  'configuration_change','low',    'Automate renewal; fail closed on validation'),
  ('CWE-204',       'User enumeration',                            'low',      '2010-01-01', true,  'code_change',          'medium', 'Uniform responses and timing'),
  ('CWE-425',       'Direct request / forced browsing',            'low',      '2008-01-01', true,  'configuration_change','low',    'Restrict zone transfers to secondaries'),
  ('CWE-1236',      'CSV injection in exports',                    'low',      '2015-01-01', true,  'code_change',          'low',    'Escape formula prefixes on export'),
  ('CWE-319',       'Cleartext transmission (missing HSTS)',       'low',      '2012-11-01', true,  'configuration_change','low',    'Enable HSTS with preload')
on conflict (code) do nothing;

with v(title, org_slug, project_slug, team_slug, rc, component, asset, description, cvss, severity, age_days) as (values
  ('SQL injection in payment callback API',              'apex','checkout-api','payments-gateway','CWE-89','Payment service (Node.js)','api.apex.example/payments/webhook','The merchant_reference parameter from the webhook payload is concatenated into a raw SQL statement, permitting stacked queries against the payments database.',9.8,'critical',6),
  ('Unsigned JWT accepted by admin session endpoint',    'apex','admin-console','iam','CWE-347','Session service (JWT)','admin.apex.example/api/session','The token verification fallback path treats tokens with no signature as valid, allowing full admin session forgery by unauthenticated attackers.',9.4,'critical',4),
  ('Production API keys embedded in public web bundle',  'apex','checkout-api','checkout-web','CWE-798','Web bundle (Vite)','cdn.apex.example/app.js','A live payment-gateway API key and a third-party signing secret ship in the minified JavaScript bundle served to every visitor.',9.2,'critical',19),
  ('Publicly exposed S3 bucket with customer PII',       'apex','statements-storage','storage-infra','CWE-732','AWS S3','s3://apex-statements-prod','The bucket policy allows anonymous list and get. Fourteen months of customer statements containing names, addresses and masked card numbers are downloadable.',9.1,'critical',11),
  ('IDOR in transaction history endpoint',               'apex','transfer-service','transfers','CWE-639','Transaction API','api.apex.example/v2/transactions','Sequential transaction IDs let any authenticated customer enumerate and read transactions belonging to other accounts.',8.6,'high',9),
  ('SSRF in webhook URL validator',                      'apex','webhook-service','webhooks','CWE-918','Webhook dispatcher','api.apex.example/webhooks','Outbound webhook target URLs are fetched without host validation and are usable to reach the cloud metadata endpoint from inside the VPC.',8.0,'high',3),
  ('Weak TLS configuration on admin panel',              'apex','admin-console','iam','CWE-326','NGINX (admin)','admin.apex.example','TLS 1.0 and 1.1 remain enabled with weak CBC cipher suites, exposing admin sessions to downgrade attacks.',7.5,'high',15),
  ('Secrets committed to public GitHub repository',      'apex','checkout-api','payments-gateway','CWE-798','GitHub repo (checkout)','github.com/apex-fintech/checkout','A rotated but unrevoked database credential remains in the git history of a public repository, recoverable from an old commit.',7.4,'high',21),
  ('Race condition in transfer confirmation flow',       'apex','transfer-service','transfers','CWE-362','Transfer service','api.apex.example/transfers/confirm','Double-spending of one-time confirmation tokens is possible when concurrent requests hit different backend instances.',7.1,'high',2),
  ('Missing rate limiting on password reset endpoint',   'apex','auth-service','identity-eng','CWE-770','Auth API','login.apex.example/reset','The reset endpoint accepts unlimited requests, enabling targeted credential stuffing and inbox flooding of customers.',6.5,'medium',1),
  ('Outdated jQuery vulnerable to XSS',                  'apex','marketing-site','web-presence','CVE-2020-11022','jQuery 3.4.0','marketing.apex.example','jQuery 3.4.0 is vulnerable to CVE-2020-11022, passing untrusted HTML from a campaign parameter into a sink method.',5.4,'medium',27),
  ('Verbose stack traces exposing framework versions',   'apex','api-gateway','edge-platform','CWE-209','API gateway','api.apex.example (all routes)','Unhandled errors return full stack traces including dependency versions, aiding targeted exploit selection.',5.3,'medium',8),
  ('Clickjacking on legacy funds-transfer form',         'apex','legacy-portal','legacy-apps','CWE-1021','Legacy portal','legacy.apex.example/transfer','The form can be embedded in an iframe on any origin and lacks framing protection headers.',4.7,'medium',13),
  ('User enumeration via login error messages',          'apex','auth-service','identity-eng','CWE-204','Login API','login.apex.example','Differential error responses reveal whether an email address belongs to a registered account.',3.5,'low',33),
  ('Zone transfer allowed on secondary nameserver',      'apex','dns-infra','netops','CWE-425','BIND DNS','ns2.apex-dns.net','The nameserver answers AXFR requests from any source, disclosing the full internal-facing DNS inventory.',3.1,'low',40),
  ('Patient records exposed in misconfigured storage bucket','meridian','intake-archive','data-platform','CWE-732','AWS S3','s3://meridian-intake-archive','The intake archive bucket permits unauthenticated access; scanned intake forms with names, birth dates and diagnoses are publicly readable.',9.3,'critical',7),
  ('Broken access control on FHIR patient endpoint',     'meridian','fhir-api','fhir-eng','CWE-285','FHIR API','fhir.meridian.example/Patient','Object-level authorization is missing: any patient token can read arbitrary records by changing the patient ID in the request path.',9.0,'critical',5),
  ('SQL injection in appointment scheduling API',        'meridian','appointment-api','scheduling-eng','CWE-89','Scheduling API','api.meridian.example/appointments','Date-range filters reach a dynamically built query without parameterization, exposing the scheduling database.',8.8,'high',10),
  ('Unencrypted PHI column in analytics warehouse',      'meridian','analytics-warehouse','analytics-eng','CWE-311','Analytics warehouse','warehouse.meridian.internal','Diagnosis codes and patient identifiers are stored in plaintext in the analytics layer, outside the encrypted operational store.',7.8,'high',16),
  ('Default credentials on medical device gateway',      'meridian','device-gateway','device-eng','CWE-798','Device gateway (vendor)','gw-clinic-3.meridian.internal','The vendor-default admin account is unchanged on an internal-facing gateway that brokers connections to clinic devices.',7.7,'high',24),
  ('Legacy service running vulnerable logging library',  'meridian','legacy-portal','legacy-maint','CVE-2021-44228','Apache Log4j 2.14','legacy-portal.meridian.internal','An internal Java portal ships a logging library vulnerable to CVE-2021-44228; reachable JNDI lookups were confirmed in a controlled test.',7.5,'high',30),
  ('Unvalidated file upload in patient document portal', 'meridian','patient-portal','portal-eng','CWE-434','Patient portal','portal.meridian.example/upload','Uploaded files are served back with their original content type from the same origin, enabling stored script execution against other patients.',6.8,'medium',12),
  ('Third-party billing API key embedded in mobile app', 'meridian','patient-portal','portal-eng','CWE-798','Mobile app bundle','MeridianCare mobile bundle','A production billing integration key is bundled in the shipped mobile app and extractable with static analysis.',6.2,'medium',18),
  ('Expired TLS certificate on integration API subdomain','meridian','integration-api','integrations','CWE-324','Integration API (TLS)','integration.meridian.example','The certificate expired without alerting; one integration path silently fell back to ignoring certificate validation.',5.9,'medium',35),
  ('Session fixation on patient portal login',           'meridian','patient-portal','portal-eng','CWE-384','Patient portal','portal.meridian.example','The session ID is not rotated on login, allowing a pre-set identifier to be inherited by the authenticated session.',5.4,'medium',9),
  ('CSV injection in exported audit reports',            'meridian','patient-portal','portal-eng','CWE-1236','Report exporter','portal.meridian.example/reports','Report exports place unescaped user-controlled text into formula cells; opening the export in a spreadsheet executes the formula.',3.8,'low',22),
  ('Missing HSTS on patient portal',                     'meridian','patient-portal','portal-eng','CWE-319','Patient portal (TLS)','portal.meridian.example','No Strict-Transport-Security header is sent, leaving first-visit connections eligible for SSL-strip interception.',3.1,'low',14),
  ('User enumeration via password reset responses',      'meridian','patient-portal','portal-eng','CWE-204','Portal auth API','portal.meridian.example/reset','The reset endpoint confirms whether an email is registered, differing from the login response behavior.',2.7,'low',28)
)
insert into bastion_v2.findings
      (org_id, department_id, project_id, team_id, root_cause_id,
       title, severity, cvss, asset, affected_component, description, detected_at)
select o.id, p.department_id, p.id, t.id, rc.id,
       v.title, v.severity::bastion_v2.severity, v.cvss, v.asset, v.component, v.description,
       now() - (v.age_days || ' days')::interval
from v
join bastion_v2.organizations o on o.slug = v.org_slug
join bastion_v2.projects p on p.org_id = o.id and p.slug = v.project_slug
join bastion_v2.teams t on t.org_id = o.id and t.slug = v.team_slug
join bastion_v2.root_causes rc on rc.code = v.rc
on conflict (org_id, title) do nothing;
