# Just Mine: turning on accounts + the leaderboard

The game is a static website (GitHub Pages), so it can't run a database itself.
It uses **Supabase**: a free hosted PostgreSQL database with a login system built in.
Until the two keys below are filled in, the game works exactly as before and just says
"Online is not set up yet".

## Steps (about 10 minutes, for a grown-up)

1. Go to <https://supabase.com>, sign up (free plan), and click **New project**.
   Pick any name and a strong database password (you won't need it for the game), region close to you.
2. When the project is ready: **SQL Editor → New query**, paste everything from `setup.sql`, press **Run**.
3. **Authentication → Sign In / Providers → Email**: turn **OFF** "Confirm email" and save.
   (Players only pick a username. The game turns it into a pretend address like
   `name@players.justmine.game`, so no real e-mail is ever asked for or sent.)
4. **Project Settings → API**: copy the **Project URL** and the **anon public** key.
5. Paste them into `index.html`, in the line that starts with `const CLOUD =`:
   ```js
   const CLOUD = { url: 'https://xxxx.supabase.co', key: 'eyJhbGciOi...' };
   ```
   (Or send them to Claude and it will put them in.)

## Progress is never lost

- Making an account **adopts the progress already on that device** and uploads it.
- Logging in keeps whichever save is further along (cloud or device); the other one is kept as a backup
  in the browser (`justmine.backups`, last 5).
- Another player logging in on the same computer gets their own save; the first player's progress stays
  in their account (and in a backup).
- With no internet nothing is changed; the game just keeps saving on the device.

## Is it safe to put the key in a public website?

Yes. The **anon** key is made to be public. Every visitor's browser gets it anyway.
What protects the data are the rules in `setup.sql` ("Row Level Security"):

- everybody can **read** the leaderboard (username + scores only)
- each player's **cloud save** (table `saves`) can only be read and written by that player
- a logged-in player can only **change their own row**, and scores can only go **up**
- nobody can delete other players or change their username
- passwords are stored by Supabase as a hash, never in this table and never in the game

**Never** put the `service_role` key in the game. That one ignores all the rules.

## Honest limit

Like every browser game, the code runs on the player's computer, so a player who
knows JavaScript could send a fake score for **their own** account. The rules stop them from touching
anyone else's row. If that ever becomes a problem, you can remove a cheater in
**Table Editor → profiles** (or **Authentication → Users**).
