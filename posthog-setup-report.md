<wizard-report>
# PostHog post-wizard report

The wizard has completed a deep integration of PostHog into your Ruby on Rails + React/Inertia.js application. Here's a summary of what was done:

- Added `posthog-ruby` and `posthog-rails` gems to the Gemfile
- Installed `posthog-js` npm package for client-side tracking
- Created `config/initializers/posthog.rb` with `PostHog.init` and `PostHog::Rails.configure` (auto-captures unhandled controller exceptions, Rails.error events, and ActiveJob failures)
- Added server-side event capture to `app/controllers/rsvps_controller.rb` (RSVP submit success and failure, with user identify on success)
- Added server-side event capture to `app/jobs/sync_rsvp_to_loops_job.rb` (Loops sync success and failure)
- Initialized posthog-js in `app/frontend/entrypoints/inertia.tsx` using `VITE_POSTHOG_KEY` and `VITE_POSTHOG_HOST` env vars
- Added client-side `rsvp_form_submitted` event and `posthog.identify` call in `app/frontend/pages/landing/index.tsx` on form submit
- Configured `.env` with `POSTHOG_PROJECT_TOKEN`, `POSTHOG_HOST`, `VITE_POSTHOG_KEY`, and `VITE_POSTHOG_HOST`

| Event | Description | File |
|---|---|---|
| `rsvp_submitted` | User successfully submitted an RSVP with their email | `app/controllers/rsvps_controller.rb` |
| `rsvp_failed` | RSVP submission failed validation (invalid/duplicate email) | `app/controllers/rsvps_controller.rb` |
| `loops_sync_completed` | RSVP email was successfully synced to Loops | `app/jobs/sync_rsvp_to_loops_job.rb` |
| `loops_sync_failed` | Syncing RSVP to Loops failed (rate limit or API error) | `app/jobs/sync_rsvp_to_loops_job.rb` |
| `rsvp_form_submitted` | User clicked submit on the RSVP form (client-side) | `app/frontend/pages/landing/index.tsx` |

## Next steps

We've built some insights and a dashboard for you to keep an eye on user behavior, based on the events we just instrumented:

- **Dashboard — Analytics basics**: https://us.posthog.com/project/348476/dashboard/1376742
  - **Total RSVPs (last 30 days)**: https://us.posthog.com/project/348476/insights/Nhmu2QUs
  - **Daily RSVPs over time**: https://us.posthog.com/project/348476/insights/8T0c46fg
  - **RSVP conversion funnel**: https://us.posthog.com/project/348476/insights/DU2zuN8R
  - **RSVP failures**: https://us.posthog.com/project/348476/insights/SjryKDlF
  - **Loops sync health**: https://us.posthog.com/project/348476/insights/GaAzsASW

### Agent skill

We've left an agent skill folder in your project at `.claude/skills/integration-ruby-on-rails/`. You can use this context for further agent development when using Claude Code. This will help ensure the model provides the most up-to-date approaches for integrating PostHog.

</wizard-report>
