-- ============================================================================
-- Bastion — 02_seed.sql
-- Memberships + findings. Requires the two demo users to already exist in
-- auth.users (created in Studio — see README / About page):
--   ada@apex.test  → Apex Financial      sam@meridian.test → Meridian Health
-- Idempotent: re-running inserts nothing new.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Memberships
-- ----------------------------------------------------------------------------
insert into public.members (org_id, user_id, role)
select o.id, u.id, 'admin'
from public.organizations o
join auth.users u on u.email = 'ada@apex.test'
where o.slug = 'apex'
on conflict do nothing;

insert into public.members (org_id, user_id, role)
select o.id, u.id, 'admin'
from public.organizations o
join auth.users u on u.email = 'sam@meridian.test'
where o.slug = 'meridian'
on conflict do nothing;

-- ----------------------------------------------------------------------------
-- Findings — Apex Financial (fintech: payments, PII, admin tooling)
-- 15 rows · 4 critical / 5 high / 4 medium / 2 low
-- ----------------------------------------------------------------------------
with org as (select id from public.organizations where slug = 'apex')
insert into public.findings
      (org_id, title, severity, status, cvss, asset, description, detected_at)
select org.id,
       v.title,
       v.severity::public.severity,
       v.status::public.finding_status,
       v.cvss,
       v.asset,
       v.description,
       now() - (v.age_days || ' days')::interval
from org,
     (values
       ('SQL injection in payment callback API',             'critical', 'open',         9.8, 'api.apex.example/payments/webhook',  'The merchant_reference parameter from the webhook payload is concatenated into a raw SQL statement, permitting stacked queries against the payments database.',  6),
       ('Unsigned JWT accepted by admin session endpoint',   'critical', 'in_progress',  9.4, 'admin.apex.example/api/session',     'The token verification fallback path treats tokens with no signature as valid, allowing full admin session forgery by unauthenticated attackers.',           4),
       ('Production API keys embedded in public web bundle',  'critical', 'resolved',     9.2, 'cdn.apex.example/app.js',            'A live payment-gateway API key and a third-party signing secret ship in the minified JavaScript bundle served to every visitor.',                              19),
       ('Publicly exposed S3 bucket with customer PII',       'critical', 'open',         9.1, 's3://apex-statements-prod',          'The bucket policy allows anonymous list and get. Fourteen months of customer statements containing names, addresses and masked card numbers are downloadable.', 11),
       ('IDOR in transaction history endpoint',              'high',     'open',         8.6, 'api.apex.example/v2/transactions',   'Sequential transaction IDs let any authenticated customer enumerate and read transactions belonging to other accounts.',                                         9),
       ('SSRF in webhook URL validator',                     'high',     'open',         8.0, 'api.apex.example/webhooks',          'Outbound webhook target URLs are fetched without host validation and are usable to reach the cloud metadata endpoint from inside the VPC.',                    3),
       ('Weak TLS configuration on admin panel',             'high',     'in_progress',  7.5, 'admin.apex.example',                 'TLS 1.0 and 1.1 remain enabled with weak CBC cipher suites, exposing admin sessions to downgrade attacks.',                                                    15),
       ('Secrets committed to public GitHub repository',     'high',     'in_progress',  7.4, 'github.com/apex-fintech/checkout',   'A rotated but unrevoked database credential remains in the git history of a public repository, recoverable from an old commit.',                                21),
       ('Race condition in transfer confirmation flow',      'high',     'open',         7.1, 'api.apex.example/transfers/confirm', 'Double-spending of one-time confirmation tokens is possible when concurrent requests hit different backend instances.',                                        2),
       ('Missing rate limiting on password reset endpoint',  'medium',   'open',         6.5, 'login.apex.example/reset',           'The reset endpoint accepts unlimited requests, enabling targeted credential stuffing and inbox flooding of customers.',                                        1),
       ('Outdated jQuery vulnerable to XSS',                 'medium',   'resolved',     5.4, 'marketing.apex.example',             'jQuery 3.4.0 is vulnerable to CVE-2020-11022, passing untrusted HTML from a campaign parameter into a sink method.',                                           27),
       ('Verbose stack traces exposing framework versions',  'medium',   'open',         5.3, 'api.apex.example (all routes)',      'Unhandled errors return full stack traces including dependency versions, aiding targeted exploit selection.',                                                  8),
       ('Clickjacking on legacy funds-transfer form',        'medium',   'open',         4.7, 'legacy.apex.example/transfer',       'The form can be embedded in an iframe on any origin and lacks framing protection headers.',                                                                   13),
       ('User enumeration via login error messages',         'low',      'resolved',     3.5, 'login.apex.example',                 'Differential error responses reveal whether an email address belongs to a registered account.',                                                                33),
       ('Zone transfer allowed on secondary nameserver',     'low',      'open',         3.1, 'ns2.apex-dns.net',                   'The nameserver answers AXFR requests from any source, disclosing the full internal-facing DNS inventory.',                                                     40)
     ) as v(title, severity, status, cvss, asset, description, age_days)
on conflict (org_id, title) do nothing;

-- ----------------------------------------------------------------------------
-- Findings — Meridian Health (healthcare: PHI, portals, integrations)
-- 13 rows · 2 critical / 4 high / 4 medium / 3 low
-- ----------------------------------------------------------------------------
with org as (select id from public.organizations where slug = 'meridian')
insert into public.findings
      (org_id, title, severity, status, cvss, asset, description, detected_at)
select org.id,
       v.title,
       v.severity::public.severity,
       v.status::public.finding_status,
       v.cvss,
       v.asset,
       v.description,
       now() - (v.age_days || ' days')::interval
from org,
     (values
       ('Patient records exposed in misconfigured storage bucket', 'critical', 'open',         9.3, 's3://meridian-intake-archive',          'The intake archive bucket permits unauthenticated access; scanned intake forms with names, birth dates and diagnoses are publicly readable.',                    7),
       ('Broken access control on FHIR patient endpoint',          'critical', 'open',         9.0, 'fhir.meridian.example/Patient',         'Object-level authorization is missing: any patient token can read arbitrary records by changing the patient ID in the request path.',                            5),
       ('SQL injection in appointment scheduling API',             'high',     'open',         8.8, 'api.meridian.example/appointments',     'Date-range filters reach a dynamically built query without parameterization, exposing the scheduling database.',                                                 10),
       ('Unencrypted PHI column in analytics warehouse',           'high',     'in_progress',  7.8, 'warehouse.meridian.internal',          'Diagnosis codes and patient identifiers are stored in plaintext in the analytics layer, outside the encrypted operational store.',                               16),
       ('Default credentials on medical device gateway',           'high',     'open',         7.7, 'gw-clinic-3.meridian.internal',        'The vendor-default admin account is unchanged on an internal-facing gateway that brokers connections to clinic devices.',                                       24),
       ('Legacy service running vulnerable logging library',       'high',     'in_progress',  7.5, 'legacy-portal.meridian.internal',      'An internal Java portal ships a logging library vulnerable to CVE-2021-44228; reachable JNDI lookups were confirmed in a controlled test.',                     30),
       ('Unvalidated file upload in patient document portal',      'medium',   'open',         6.8, 'portal.meridian.example/upload',       'Uploaded files are served back with their original content type from the same origin, enabling stored script execution against other patients.',               12),
       ('Third-party billing API key embedded in mobile app',      'medium',   'in_progress',  6.2, 'MeridianCare mobile bundle',           'A production billing integration key is bundled in the shipped mobile app and extractable with static analysis.',                                               18),
       ('Expired TLS certificate on integration API subdomain',    'medium',   'resolved',     5.9, 'integration.meridian.example',         'The certificate expired without alerting; one integration path silently fell back to ignoring certificate validation.',                                          35),
       ('Session fixation on patient portal login',                'medium',   'open',         5.4, 'portal.meridian.example',              'The session ID is not rotated on login, allowing a pre-set identifier to be inherited by the authenticated session.',                                            9),
       ('CSV injection in exported audit reports',                 'low',      'open',         3.8, 'portal.meridian.example/reports',      'Report exports place unescaped user-controlled text into formula cells; opening the export in a spreadsheet executes the formula.',                              22),
       ('Missing HSTS on patient portal',                          'low',      'open',         3.1, 'portal.meridian.example',              'No Strict-Transport-Security header is sent, leaving first-visit connections eligible for SSL-strip interception.',                                             14),
       ('User enumeration via password reset responses',           'low',      'resolved',     2.7, 'portal.meridian.example/reset',        'The reset endpoint confirms whether an email is registered, differing from the login response behavior.',                                                       28)
     ) as v(title, severity, status, cvss, asset, description, age_days)
on conflict (org_id, title) do nothing;
