# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Salesforce DX project (`ETH-SDX`, source API 67.0) for an SOS Children's Villages org running **NPSP** (Nonprofit Success Pack). It is Apex-heavy: ~100 classes, 3 triggers, one Aura bundle, no LWC. The custom code does three things:

1. Accepts donations from the **Kentico** website and the **ArifPay** payment gateway via Apex REST, creating NPSP Recurring Donations / Opportunities / Payments.
2. Drives the donor lifecycle with **email notifications and follow-up Tasks** (welcome, thank-you, milestones, birthdays, anniversaries, reminders, cancellations).
3. Contains an older **DPO** payment-gateway integration (XML API) that is still in the tree.

Ticket IDs in comments (`SFESWCSD-85`, `-86`, `-91`, `-92`, `-74`, `-40`) are Jira references; commit messages and manifest names (`manifest/package85.xml`, `package85_86_91_Fixes.xml`) use the same numbers. Keep adding the ticket comment on new code so changes stay traceable.

Also read `AGENTS.md` (style, PR expectations) — it is the repo's existing contributor guide.

## Commands

Default target org is the `eth-sdx` sandbox (`.sf/config.json`). Always pass `--target-org` explicitly when you mean a different org.

```powershell
# JS tooling (only relevant for aura/ — there is no LWC yet)
npm install
npm run lint                 # eslint on aura/lwc JS
npm run prettier:verify      # check formatting (Apex, XML, JS, etc.)
npm run prettier             # format; also runs on commit via husky + lint-staged
npm test                     # sfdx-lwc-jest (no LWC tests exist today)

# Deploy / validate
sf project deploy start --source-dir force-app --target-org eth-sdx --dry-run
sf project deploy start --source-dir force-app/main/default/classes/Foo.cls --source-dir force-app/main/default/classes/FooTest.cls --target-org eth-sdx --test-level RunSpecifiedTests --tests FooTest --wait 10
sf project deploy start --manifest manifest/package.xml --target-org eth-sdx   # package.xml currently = all ApexClass
sf project retrieve start --source-dir force-app --target-org eth-sdx

# Apex tests
sf apex run test --target-org eth-sdx --test-level RunLocalTests --wait 20 --code-coverage --result-format human
sf apex run test --target-org eth-sdx --tests RecurringDonationTest --wait 10 --result-format human
sf apex run test --target-org eth-sdx --tests OpportunityTest.testSomething --wait 10   # single method

# Anonymous Apex helpers (see scripts/apex/*.md for caveats)
sf apex run --file scripts/apex/runSendEmailNotificationBatch.apex --target-org eth-sdx   # preview-only by default (EXECUTE_FOR_REAL=false)
sf apex run --file scripts/apex/arifpaySandboxProbe.apex --target-org eth-sdx             # real callouts to ArifPay sandbox
```

Test classes are colocated in `classes/` and named either `XxxTest` (`RecurringDonationTest`, `OpportunityTest`, `LeadTest`) or `XxxServiceTest`; there are no test suites. `InsertWSDataTest` and `KenticoDonationRestServiceTest` are the large integration-style tests for the REST intake.

`.forceignore` excludes `**/__tests__/**`, `jsconfig.json`, `.eslintrc.json`. `manifest/` holds per-ticket package.xml files used for partial deploys; `outputs/` and `.codex_tmp/` are scratch artifacts, not deployable.

## Architecture

### Trigger → Handler → Service (one trigger per object)

```
OpportunityTrigger          → OpportunityHandler       → IOpportunityService / OpportunityService
PaymentTrigger (npe01__OppPayment__c) → PaymentTriggerHandler → IPaymentTriggerService / PaymentTriggerService
RecurringDonationTrigger (npe03__Recurring_Donation__c) → RecurringDonationHandler → IRecurringDonationService / RecurringDonationService
```

Triggers only dispatch on context; handlers list which service methods run per event (and carry the ticket comments explaining why); services hold the logic. Services expose both **static** methods used by the REST layer (`registerDonation`, `createSponsorship`, `buildPayment`) and **instance** methods used by the trigger path (`sendSponsorshipWelcomeEmail`, `closeOldRDs`, ...). Business-rule builders are `@TestVisible private static` (`build*Targets`, `build*Tasks`) so tests can assert on the computed recipient/task sets without DML or email.

`ContactHandler`/`ContactService`, `LeadHandler`/`LeadService`, `AccountService`, `CampaignService`, `ValidationService` follow the same split and are called from the intake services (there is no Contact/Lead trigger checked in).

### Donation intake (Kentico → ArifPay → Salesforce), ticket SFESWCSD-92

Three Apex REST endpoints, numbered "1st/2nd/3rd WS" in comments:

| Endpoint | Class | Purpose |
|---|---|---|
| `POST /services/apexrest/donation/oneOffCommitted/*` | `OneOffCommittedDonationRestService` | Kentico sends a `DonationRequest`; `RecurringDonationService.registerDonation` creates Account/Contact/RD/Opportunity/Payment |
| `POST /services/apexrest/donation/sponsorship/*` | `SponsorshipDonationRestService` | Same payload, routes to `registerSponsorship` (generates `Sponsorship_ID__c` from village code) |
| `POST /services/apexrest/arifpay/payments/*` | `ArifPayCallbackRestService` | ArifPay payment callback → `CallbackService.process`; sub-paths `/success`, `/cancel`, `/notify`, `/error` only write a `Log__c` |
| outbound | `ArifPayCancellationService` (+ `ArifPayCancellationQueueable`) | Salesforce calls ArifPay to cancel a subscriber |

Shared pieces: `DonationRequest`/`DonationResponse`/`ErrorResponse` DTOs, `ApiConstants` (all picklist/status/stage string literals — use these, do not hardcode), `DonationException` (→ HTTP 500) vs `DonationValidationException` (→ HTTP 400). Sample payloads for every flow live in `scripts/requests/*.json`.

`CallbackService.process` is the payment state machine: it matches the callback month against `npe01__Scheduled_Date__c` / `Scheduled_Date_2nd_Attempt__c` / `Scheduled_Date_3rd_Attempt__c` on the Payment, increments `Failed_Payment_Attempts__c`, moves the Opportunity to `Closed Won` or `Missed`, and after 3 failures writes off the payment and back-fills earlier pledged installments. Touch this only with the retry-attempt semantics in mind.

ArifPay config lives in the `Arifpay_Config__mdt` custom metadata (endpoint, merchant key, bearer token) read by `ArifpayService`. `ArifpayWebAPI` (`/arifpay/chargeDonation`) and `ArifpayRecurringScheduler` are the earlier SFESWCSD-74 prototype and are not the production callback path.

### Donor lifecycle emails and tasks (SFESWCSD-85/86/91)

Two generations coexist:

- **Legacy path**: `Utils.sendEmailByTemplate(...)` with classic EmailTemplate names (`Utils.emailTemplateThankYouEmail`, etc.), still used by `PaymentTriggerService.checkPaymentsWithRDToNotify`.
- **DLE (Donor Lifecycle Engine)**: `DLE_EmailDispatchService.sendEmail(eventKey, Map<WhoId, WhatId>)`. The event key is a `DLE_Email_Dispatch_Config__mdt` DeveloperName (the string constants in `Utils`, e.g. `Utils.THANK_YOU_EMAIL_AFTER_6`, `Utils.WELCOME_THE_NEW_DONO`). Config resolves via `DLE_EmailDispatchConfigResolver` (cached `getInstance`, mockable with `@TestVisible mock`). Every send is logged to `DLE_Email_Log__c`; `DLE_Engine_Settings__c` (hierarchy custom setting) has `Disable_All_Sends__c` (kill switch) and `Disable_Send_Logging__c`; `DLE_Recipient_Suppression__mdt` blocks recipients by field value. Per-recipient attachments come from a class implementing `DLE_EmailAttachmentProvider` named on the config row. New email features should use the DLE path.

Scheduled/batch senders: `SendEmailNotificationBatch(templateKey)` (implements both `Batchable` and `Schedulable`; the query in `start()` switches on the template key — birthdays, anniversaries, year-end reports, reminders, one-time-donor follow-ups), `SendEmailHolidaysNotificationBatch`, `SendNotificationNewLeadsBatch`, `SendWSErrorsBatch`. The `System.schedule(...)` lines to install each job are kept as comments at the top of the batch class.

Other scheduled jobs: `CloseStalePledgedOpportunitiesBatch`/`Scheduler`, `CloseOppsDefeatedBatch`, `CreateNextOpportunityBatch`, `UpdateOpportunityStatusesBatch`, `TransactionScheduler` (emails and purges the day's `Transaction__c` JSON log).

### Legacy Kentico/DPO intake

`InsertWSData` (`/services/apexrest/InsertWSData/*`) is the older, monolithic Kentico endpoint: it stores the raw JSON in `Transaction__c`, parses it via `WSUtilsV2.WSV2` / `WSKentico`, and creates NPSP records with retry fields (`Attempts__c`). `DPOHandler`/`DPOUtils`/`DPOClasses`/`DPOXMLResponse`/`DPOReadTransactionBatch` poll the DPO gateway's XML API for settled transactions; credentials come from the `DPO__c` hierarchy custom setting. Prefer the SFESWCSD-92 services for new work; keep these compiling since `InsertWSDataTest` is the largest test in the org.

### Data model notes

- NPSP managed objects are checked in under `objects/` (`npe01__OppPayment__c`, `npe03__Recurring_Donation__c`, `npsp__*` fields) so that custom fields on them deploy; do not edit the managed `npe*`/`npsp__` field files.
- Custom fields that drive the logic: on RD — `Donation_ID__c` (Kentico UUID used to match callbacks), `Donation_Type__c`, `Donor_Type__c`, `Sponsorship_*__c`, `Arifpay_Transaction_Id__c`; on Payment — `Status__c`, `Failed_Payment_Attempts__c`, `Scheduled_Date_2nd/3rd_Attempt__c`, `Transaction_Ref__c`; on Opportunity — `Donation_Type__c`, `Donor_Type__c` (85 custom fields, 6 record types).
- `Log__c` is the generic request/error log (`Utils.logJsons`); `Transaction__c` stores raw inbound JSON.
- `Facer_Campaign__c`, `Location__c`, `Other_Participation__c` model street fundraisers ("facers") and village locations used for sponsorship IDs.

### Utils

`Utils.cls` is the grab-bag: email template constants, org-wide address, notification recipients (hardcoded emails — change deliberately), picklist validation, cron-string builder, `sendEmailByTemplate`, `createNotification` (Task factory), `isSandbox`, `getAlpha2Code`. Check here before adding a helper elsewhere.

## Conventions specific to this repo

- Four-space indentation, no trailing commas (Prettier config); `prettier-plugin-apex` formats `.cls`/`.trigger`.
- Class headers use the `@File Name / @Description / @Author` block; new logic gets a `//SFESWCSD-nn` comment at the method or handler call site.
- Interfaces are `I`-prefixed (`IOpportunityService`); handlers instantiate services through the interface.
- Bulk-safe: collect IDs from `Trigger.new`, one query per object, never query or DML inside a loop over records. Existing code uses `Database.update(list, false)` for best-effort writes with `System.debug('###...')` traces; match that when extending it.
- REST classes are `global inherited sharing`; services are `public` (some `inherited sharing`). Preserve sharing keywords when refactoring.
- When adding a new REST endpoint or callback shape, add a matching sample under `scripts/requests/` and a mocked test in the style of `KenticoDonationRestServiceTest` / `ArifPaySandboxProbeTest` (`HttpCalloutMock`, no live callouts in tests).
