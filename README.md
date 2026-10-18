# CFC Household Shepherd

A pastoral care app for Couples for Christ Household, Unit and Chapter Servants.
It is hosted free on GitHub Pages, and Supabase handles sign-in and data.

© 2026 PCANetwork. All Rights Reserved.

## What's in this folder

| File | What it is |
|---|---|
| `index.html` | The app itself |
| `schema.sql` | Database setup script, which you run once in Supabase |
| `manifest.webmanifest`, `icon-192.png`, `icon-512.png` | Let leaders add the app to their phone's home screen |

---

## Part 1: Set up Supabase (about 10 minutes)

### 1. Create the project
1. Sign in at supabase.com and click **New project**.
2. Name it `cfc-shepherd`, set a strong database password, and save that password somewhere safe.
3. For **Region**, choose **Southeast Asia (Singapore)**, the closest region to the Philippines.
4. Wait about a minute for the project to finish setting up.

### 2. Create the tables and security rules
1. In the left menu, open **SQL Editor** and click **New query**.
2. Open `schema.sql`, copy everything in it, paste it into the editor, and click **Run**.
3. You should see "Success. No rows returned."

### 3. Configure sign-in
Go to **Authentication > Sign In / Providers** (or **Providers > Email** in older dashboards).
- Keep **Email** enabled.
- Turn **Confirm email** OFF.

  Supabase's free built-in email service sends only a few emails per hour, so confirmation emails would block leaders from signing up. Turning it off is safe, because no new account can see or save anything until a Chapter Servant approves it in the app.

### 4. Copy your keys
Go to **Project Settings > API Keys** (or click **Connect** at the top). Copy these two values:
- **Project URL**, which looks like `https://abcdxyz.supabase.co`
- **anon / publishable key**, a long string

**Never use the `service_role` or secret key in the app.**

### 5. Put the keys in the app
Open `index.html` in a text editor (GitHub's web editor works too) and find these lines near the top of the script:

```js
const SUPABASE_URL = "https://YOUR-PROJECT.supabase.co";
const SUPABASE_ANON_KEY = "YOUR-ANON-KEY";
```

Replace them with your two values and save.

The anon key is designed to be public. The database's row-level security rules are what protect the data.

---

## Part 2: Publish on GitHub Pages (about 5 minutes)

1. On GitHub, click **New repository** and name it `cfc-shepherd`.
2. Set it to **Public**. GitHub Pages is free only for public repositories.

   Only the app's code is public. Member names and notes live in Supabase, protected by sign-in.
3. Click **Add file > Upload files**. Drag in all five files (`index.html`, `schema.sql`, `manifest.webmanifest`, `icon-192.png`, `icon-512.png`, plus this README) and click **Commit changes**.
4. Go to **Settings > Pages**. Under **Build and deployment**, set Source to **Deploy from a branch**, Branch to **main**, and folder to **/ (root)**. Click **Save**.
5. After 1–2 minutes, the app is live at:
   `https://YOUR-GITHUB-USERNAME.github.io/cfc-shepherd/`

Finally, tell Supabase where the app lives:
- Go to **Supabase > Authentication > URL Configuration**.
- Set **Site URL** to your GitHub Pages address.

---

## Part 3: Become the first Chapter Servant

1. Open your app link and choose **Create account** with your own email.
2. You'll see "Waiting for approval." That's expected for the very first account.
3. In **Supabase > SQL Editor**, run this with your email:

   ```sql
   update public.profiles set role = 'chapter' where email = 'you@example.com';
   ```

4. Reload the app. You now have the **Chapter** tab, including the **Leaders** list.

From now on, you never need Supabase to manage people.

---

## Part 4: Onboard your leaders

1. Send the app link to your Unit Servants and Household Servants.
2. Each one creates an account and sees "Waiting for approval."
3. You open **Chapter > Leaders**, set each person's **role** and **unit**, and tap **Save**.

   Unit names must be typed exactly the same for everyone in that unit. For example, use `Unit 1` every time, not sometimes `unit 1`.
4. They reload the page and can start working.

**What each role can see:**

| Role | Own folder | Referrals | Overview |
|---|---|---|---|
| Household Servant | Yes | Sends, and sees replies | — |
| Unit Servant | Yes | Receives from their unit | Their unit's households (counts only) |
| Chapter Servant | Yes | Receives from everyone | The whole chapter (counts only) + Leaders list |

**Nobody, including Chapter Servants and the Supabase admin screen user, sees another leader's members or pastoral notes in the app.**

One exception is worth knowing: whoever controls the Supabase project can technically read the raw database. So keep the Supabase account in trusted hands, with a strong password and two-factor authentication turned on.

### Install on phones
- **Android (Chrome):** open the link, tap **⋮**, then **Add to Home screen**.
- **iPhone (Safari):** open the link, tap **Share**, then **Add to Home Screen**.

---

## Moving data from the claude.ai version

1. In the claude.ai version, go to **Export > Download backup**.
2. In this version, go to **Export > Restore from backup** and choose that file.

Leaders use the same two steps when handing over a household to the next Household Servant.

## Everyday maintenance

**Forgotten password**
- Go to **Supabase > Authentication > Users**, open the person, and choose **Send password recovery**, or delete the user so they can sign up again.
- Built-in recovery emails are rate-limited. If you'll need many emails, add your own email sender under **Authentication > SMTP Settings**. A free Brevo or Resend account works.

**Someone leaves their role**
- First, they download a backup for their successor.
- Then you set their role to **Waiting for approval** in **Leaders**. This immediately removes their access.

**Free plan limits**
- Supabase pauses free projects after **7 days with no activity**. Regular use keeps it awake. If it does pause, click **Restore** in the dashboard and nothing is lost.
- Free storage (500 MB) is far more than a chapter needs.

**Updating the app**
- Upload a new `index.html` to the repository. GitHub Pages refreshes within a couple of minutes.
- Keep your two Supabase values in the new file.

## Privacy

The app holds sensitive personal information covered by the Philippine Data Privacy Act (RA 10173). Before rollout:
- Get your Chapter or Area leadership's approval.
- Tell members that leaders keep pastoral notes, and get their consent.
- Agree on what should never be written down.
