-- this file was manually created
INSERT INTO public.users (display_name, email, handle, cognito_user_id)
VALUES
  ('Ionel Pacurariu', 'jonny_boy90609@yahoo.com', 'ionelp' ,'e2d787ae-5a98-4d02-890e-7231a9a06d2d'),
  ('Andrew Bayko','bayko@exampro.co' , 'bayko' ,'MOCK'),
  ('Londo Mollari', 'lmollari@centari.com','londo','MOCK');

INSERT INTO public.activities (user_uuid, message, expires_at)
VALUES
  (
    (SELECT uuid from public.users WHERE users.handle = 'ionelp' LIMIT 1),
    'This was imported as seed data!',
    current_timestamp + interval '10 day'
  )