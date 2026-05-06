# Firebase Analytics Launch Insights

Use this guide after the analytics events ship in an App Store build. Debug, TestFlight, sandbox-receipt, debugger-attached, and demo workspace sessions are intentionally excluded from production Firebase collection.

## Custom Definitions

In Firebase or GA4, open Admin > Data display > Custom definitions and create event-scoped custom dimensions for:

- `source`
- `mode`
- `step_name`
- `current_stage`
- `completion_outcome`
- `plan`
- `product_id`
- `error_type`
- `restore_outcome`
- `method`

Create custom metrics for:

- `elapsed_seconds`
- `step_duration_seconds`
- `session_day`

Mark these events as key events:

- `setup_completed`
- `purchase_completed`
- `first_activation`
- `retention_day_1`
- `retention_day_3`
- `retention_day_7`

## Funnel Explorations

Create a Paywall Funnel exploration:

1. `paywall_viewed`
2. `paywall_plan_selected`
3. `purchase_started`
4. `purchase_completed`

Break down by `plan` or `product_id` to compare Lifetime, Annual, and Monthly.

Create a Post-Paywall Setup Funnel exploration:

1. `setup_started`
2. `setup_step_completed` where `step_name = purpose`
3. `setup_step_completed` where `step_name = fulfillment`
4. `setup_step_completed` where `step_name = goal`
5. `setup_step_completed` where `step_name = capture`
6. `setup_completed`

Turn on elapsed time to inspect how long users take between steps.

## Drop-Off And Timing

Create a Free-form exploration for setup drop-off:

- Filter: `event_name = setup_exited`
- Rows: `step_name`
- Values: total users, event count, average `elapsed_seconds`, average `step_duration_seconds`
- Optional breakdown: `completion_outcome`

This answers where unfinished users quit and how long they stayed before leaving.

## Retention And Revenue

Create cohort explorations:

- Inclusion: `first_open`; return criterion: any event; granularity: daily; inspect D1, D3, and D7.
- Inclusion: `setup_completed`; return criterion: any event; granularity: daily; compare activated-user retention.

Approximate “% never return after first session” as `100% - D1 retention` for the `first_open` cohort.

Use Monetization > In-app purchases for revenue captured. Firebase's StoreKit transaction integration should populate purchase revenue; use `product_id` or item/product breakdowns to compare plans.
