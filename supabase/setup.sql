-- ============================================================
-- Rawand Aldeeb Studio — database setup (run once in Supabase SQL Editor)
-- ============================================================

-- Who is the admin
create or replace function public.is_admin() returns boolean
language sql stable as $$
  select coalesce(lower(auth.jwt() ->> 'email') = 'rawandrr1989@gmail.com', false)
$$;

-- ---------- Requests (form submissions) ----------
create table if not exists public.requests (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  service text check (char_length(service) <= 80),
  budget text check (char_length(budget) <= 80),
  name text check (char_length(name) <= 120),
  contact text check (char_length(contact) <= 120),
  message text check (char_length(message) <= 3000),
  lang text check (lang in ('ar','en')),
  status text not null default 'new' check (status in ('new','in_progress','done')),
  note text check (char_length(note) <= 3000)
);
alter table public.requests enable row level security;
drop policy if exists "public can send requests" on public.requests;
create policy "public can send requests" on public.requests
  for insert to anon, authenticated with check (status = 'new' and note is null);
drop policy if exists "admin manages requests" on public.requests;
create policy "admin manages requests" on public.requests
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------- Analytics events ----------
create table if not exists public.events (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  type text not null check (char_length(type) <= 40),
  label text check (char_length(label) <= 160),
  path text check (char_length(path) <= 160),
  ref text check (char_length(ref) <= 160),
  device text check (device in ('mobile','tablet','desktop')),
  lang text check (lang in ('ar','en')),
  sid text check (char_length(sid) <= 40)
);
create index if not exists events_created_idx on public.events (created_at desc);
alter table public.events enable row level security;
drop policy if exists "public can log events" on public.events;
create policy "public can log events" on public.events
  for insert to anon, authenticated with check (true);
drop policy if exists "admin reads events" on public.events;
create policy "admin reads events" on public.events
  for select to authenticated using (public.is_admin());
drop policy if exists "admin deletes events" on public.events;
create policy "admin deletes events" on public.events
  for delete to authenticated using (public.is_admin());

-- ---------- Reviews ----------
create table if not exists public.reviews (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  name_ar text not null, name_en text,
  project_ar text, project_en text,
  text_ar text not null, text_en text,
  rating int not null default 5 check (rating between 1 and 5),
  avatar text not null default 'woman' check (avatar in ('woman','man')),
  sort int not null default 100,
  published boolean not null default true
);
alter table public.reviews enable row level security;
drop policy if exists "public reads published reviews" on public.reviews;
create policy "public reads published reviews" on public.reviews
  for select to anon, authenticated using (published or public.is_admin());
drop policy if exists "admin manages reviews" on public.reviews;
create policy "admin manages reviews" on public.reviews
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------- Projects ----------
create table if not exists public.projects (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  title_ar text not null, title_en text,
  category text not null check (category in ('social','logo','identity','motion')),
  desc_ar text, desc_en text,
  images jsonb not null default '[]'::jsonb,
  sort int not null default 100,
  published boolean not null default true
);
alter table public.projects enable row level security;
drop policy if exists "public reads published projects" on public.projects;
create policy "public reads published projects" on public.projects
  for select to anon, authenticated using (published or public.is_admin());
drop policy if exists "admin manages projects" on public.projects;
create policy "admin manages projects" on public.projects
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------- Image storage ----------
insert into storage.buckets (id, name, public)
values ('work', 'work', true)
on conflict (id) do update set public = true;
drop policy if exists "admin uploads work" on storage.objects;
create policy "admin uploads work" on storage.objects
  for insert to authenticated with check (bucket_id = 'work' and public.is_admin());
drop policy if exists "admin updates work" on storage.objects;
create policy "admin updates work" on storage.objects
  for update to authenticated using (bucket_id = 'work' and public.is_admin());
drop policy if exists "admin deletes work" on storage.objects;
create policy "admin deletes work" on storage.objects
  for delete to authenticated using (bucket_id = 'work' and public.is_admin());

-- ---------- Current reviews (only added if the table is empty) ----------
insert into public.reviews (name_ar, name_en, project_ar, project_en, text_ar, text_en, rating, avatar, sort)
select * from (values
  ('مريم العنزي', 'Mariam Al-Anazi', 'تصميم سوشيال ميديا', 'Social media design', 'مبدعة ومحترفة في عملها، تهتم بالتفاصيل وتحرص على رضا العميل. النتيجة كانت فوق التوقعات، ولن يكون هذا آخر تعامل بيننا.', 'Creative and professional, she pays attention to detail and cares about client satisfaction. The result exceeded expectations, and this won’t be our last project together.', 5, 'woman', 1),
  ('أبو عمر', 'Abu Omar', 'تصميم شعار', 'Logo design', 'أكثر ما أعجبني في التعامل مع روند هو صبرها ومرونتها في تنفيذ الملاحظات. لم تتوقف حتى تأكدت أن التصميم مناسب تمامًا لما أحتاجه. شكرًا على هذا العمل الرائع.', 'What I liked most about working with Rawand was her patience and flexibility with feedback. She didn’t stop until she was sure the design fit exactly what I needed. Thank you for this great work.', 5, 'man', 2),
  ('محمد إبراهيم', 'Mohammed Ibrahim', 'تصاميم سوشيال ميديا', 'Social media designs', 'التصاميم كانت جميلة ومتناسقة مع هوية مشروعنا. روند مبدعة ومتعاونة، وتفهم المطلوب من أول مرة. سعيدة جدًا بالتعامل معها.', 'The designs were beautiful and consistent with our project’s identity. Rawand is creative and cooperative, and understands what’s needed from the first time. Very happy working with her.', 5, 'man', 3),
  ('فاطمة زعرب', 'Fatima Zorob', 'هوية بصرية', 'Visual identity', 'كنت أبحث عن هوية بصرية تعبّر عن مشروعي، وروند استطاعت تحويل أفكاري إلى تصميم متكامل ومميز. أعجبني اهتمامها بالتفاصيل وحرصها على تقديم أفضل نتيجة.', 'I was looking for a visual identity that expresses my project, and Rawand turned my ideas into a complete, distinctive design. I loved her attention to detail and her care to deliver the best result.', 5, 'woman', 4),
  ('عميل على منصة العمل الحر', 'Freelance platform client', 'تصميم منشور سوشيال ميديا', 'Social media post design', 'أنصح بشدة بالتعامل معها… لطيفة جداً وتعرف عملها تماماً. التصميم الذي أرسلته رائع ويلبّي احتياجاتي بالضبط، وكل المطلوب أُنجز بالكامل وفي وقت قصير جداً. سأتعامل معها بالتأكيد في أعمالي القادمة. روند، أنتِ خبيرة… استمري.', 'I highly recommend this freelancer… she is very kind and knows exactly her work. The design that she sent me looks great and awesome. The design meets exactly my needs. All things required has been completely done. I will definitely hire her again for my future works. The work has been done in a very short time. Rawand, you are an expert… keep it up.', 5, 'woman', 5),
  ('عميل على منصة العمل الحر', 'Freelance platform client', 'تصاميم بطاقات هدايا وأظرف', 'Gift card & envelope designs', 'مبدعة جداً ولطيفة ومتعاونة، والعمل معها سهل. شرحت المطلوب مرة واحدة فقط ونفّذت كل شيء بشكل صحيح ومثالي وفي وقت قياسي! من الصعب أن تجد مستقلاً بهذه الموهبة هذه الأيام. سأعمل معها مجدداً بالتأكيد!', 'Extremely creative and super friendly and helpful + really easy to work with. Only gave the job description once and she got everything right and perfectly done with a time record! Really hard to get hold of a freelancer with all this talent nowadays! Definitely going to work with her again!!', 5, 'man', 6),
  ('أ. حمد', 'Mr. Hamad', 'تصميم كتاب', 'Book design', 'قدّمت روند التصميم الكامل لمشروع كتابي. مبدعة ونفّذت العمل تماماً كما أردنا، وتتميز بأنها متعاونة ومتفهّمة وصبورة ومبدعة. أنصح بالعمل معها، ولن أتردد في طلبها لأي عمل جديد. شكراً روند.', 'Rawand provided the full design of my book project. She is creative and did my job exactly as we wished. She has the following qualities: helpful, understanding, patient and creative. I recommend working with her, and if I need a new job, I will not hesitate to ask her to do it. Thank you Rawand.', 5, 'man', 7),
  ('عميل على منصة العمل الحر', 'Freelance platform client', 'تصميم شعار', 'Logo design', 'نفّذت روند ما طلبته بالضبط، وكانت مثابرة حتى أنجزت المهام بما يرضيني. عمل رائع، وسأتعامل معها بالتأكيد في أعمال قادمة.', 'Rawand did exactly what I had asked for. She was relentless to complete the tasks to my satisfaction. Great work. Will definitely be using her for future work.', 5, 'man', 8),
  ('عميل على منصة العمل الحر', 'Freelance platform client', 'تصاميم إعلانات', 'Ad designs', 'مصممة فوتوشوب رائعة جداً، وسريعة في الرد، وتهتم بكل التفاصيل. سعيد جداً بالعمل معك.', 'Very great Photoshop designer and quick response, also she takes care of each detail. Really happy working with you.', 5, 'woman', 9),
  ('عميل على منصة العمل الحر', 'Freelance platform client', 'مشروع تصميم', 'Design project', 'سعيد بالتعامل معك، وأكثر ما أعجبني الاحترافية وسرعة التنفيذ والمرونة في التعديلات. يسعدني التعامل معك مرة أخرى.', 'Happy to deal with you, and the thing I liked most is the professionalism, speed of implementation and flexibility in modifications. I am happy to deal with you again.', 5, 'man', 10)
) v(name_ar, name_en, project_ar, project_en, text_ar, text_en, rating, avatar, sort)
where not exists (select 1 from public.reviews);
