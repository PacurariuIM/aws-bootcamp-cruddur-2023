-- this file was manually created
INSERT INTO public.users (display_name, email, handle, cognito_user_id)
VALUES
  ('Ionel', 'jonny_boy90609@yahoo.com', 'cheloo' ,'55de3fed-814d-4fe0-b6cb-e35ff25b5705'),
  ('Ionel', 'ionel.crazyfroggg@gmail.com', 'crazyfrog' ,'MOCK'),
  ('Andrew Bayko','bayko@exampro.co' , 'bayko' ,'MOCK'),
  ('Londo Mollari','lmollari@centari.com' ,'londo' ,'MOCK');

INSERT INTO public.activities (user_uuid, message, expires_at)
VALUES
  (
    (SELECT uuid from public.users WHERE users.handle = 'cheloo' LIMIT 1),
    'This was imported as seed data!',
    current_timestamp + interval '10 day'
  ),
  (
    (SELECT uuid from public.users WHERE users.handle = 'crazyfroggg' LIMIT 1),
    'I am the other!',
    current_timestamp + interval '10 day'
  );