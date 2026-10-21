# Production (eth-prod) vs repo - gap list for the remaining tickets (85, 86, 91, 92, 108)

Compared 2026-10-21, read-only. Ticket 113 is already deployed (deploy id 0AfaA000000uhThSAI).
Production has the Donor Lifecycle Engine v1.9 installed (58 DLE_ classes, 8 DLE objects), so DLE_ classes are NOT part of this list.
Prod DLE_EmailDispatchService has the 3-arg customFieldsByWho overload and Account recipients, so the new code compiles against it.

## 1. Apex classes

### New in production (44)
- Shared / DTOs: ApiConstants, ApiResponse, DonationException, DonationRequest, DonationResponse, DonationValidationException, ErrorResponse, ValidationService, ValidationServiceTest
- Services: AccountService, AccountServiceTest, CampaignService
- Kentico / REST intake: OneOffCommittedDonationRestService, SponsorshipDonationRestService, KenticoDonationRestServiceTest
- ArifPay: ArifPayCallbackRequest, ArifPayCallbackResponse, ArifPayCallbackRestService, ArifPayCancellationQueueable, ArifPayCancellationRequest, ArifPayCancellationService, ArifPayNotifyUrlQueueable, ArifPayPaymentsRestServiceTest, ArifPayRDCancellationQueueable, ArifPaySandboxProbe, ArifPaySandboxProbeTest, ArifPaySubscriber, ArifPaySubscriberCancellationQueueable, ArifPaySubscriberListResponse, ArifpayRecurringScheduler, ArifpayService, ArifpayWebAPI, CallbackService
- TDTM handlers: OpportunityHandler_TDTM, PaymentTriggerHandler_TDTM, RecurringDonationHandler_TDTM, RecurringDonationHandler_TDTMTest, RecurringDonationAutomationTest
- Email batches: SendEmailNotificationBatch, SendEmailNotificationBatchTest, SendEmailNotificationBatchRDTest
- Stale pledged: CloseStalePledgedOpportunitiesBatch, CloseStalePledgedOpportunitiesBatchTest, CloseStalePledgedOpportunitiesScheduler

### Changed vs production (16)
ContactService, DPOReadTransactionBatch, IOpportunityService, IPaymentTriggerService, IRecurringDonationService, LeadService, OpportunityHandler, OpportunityService, OpportunityTest, PaymentTriggerService, RecurringDonationHandler, RecurringDonationService, RecurringDonationTest, Utils, UtilsTest, GenerateHistoricOppsBatchTest (production copy omits one test on purpose)

### Triggers changed (3)
OpportunityTrigger, PaymentTrigger, RecurringDonationTrigger (repo versions are deprecated shells because logic moved to TDTM; prod RecurringDonationTrigger already has the 113 hook)

## 2. Custom objects
- Arifpay_Config__mdt (missing; fields Active__c, Bearer_Token__c, Endpoint__c, Merchant_API_Key__c, Token_Expiry__c). Credentials are data, enter them in prod by hand.

## 3. Custom fields missing in production (21)
| Object | Fields |
|---|---|
| npe03__Recurring_Donation__c | Arifpay_Transaction_Id__c, Payment_Type__c, Sponsorship_Age_Preference__c, Sponsorship_ID__c, Sponsorship_Location__c, Sponsorship_Preference__c |
| npe01__OppPayment__c | Failed_attempt_date__c, Failed_Payment_Attempts__c, Scheduled_Date_2nd_Attempt__c, Scheduled_Date_3rd_Attempt__c, Transaction_Date__c |
| Contact | Child_Data_Safeguarding__c, Personal_Data_Consent__c |
| Lead | Birthdate__c, Mailing__c |
| Opportunity | Transaction_Date__c |
| Arifpay_Config__mdt | Active__c, Bearer_Token__c, Endpoint__c, Merchant_API_Key__c, Token_Expiry__c |

## 4. Picklist values missing in production
- Opportunity.StageName: **Missed** (standard value set; reminders and the payment state machine use it). Declined already exists.
- Contact.Source__c: Web, Sponsorship, Website
- npe03__Recurring_Donation__c.Sponsorship_Type__c: Education, Child Sponsorship, Family Sponsorship, Program Sponsorship, Sponsorship

## 5. Already in production (no action)
Record types (Account 2, Campaign 4, Opportunity 6), ArifPay_Gateway remote site, auraNewLeadConvert, NPSP_Home page, DLE objects (Email Log, Engine Settings, Scheduled Send, Scheduled Task, Notification Group/Member, dispatch config, suppression), 2 suppression rules (Contact_Opted_Out, Lead_Opted_Out), objects Account/Campaign/DPO__c/Facer_Campaign__c/Location__c/Log__c/Other_Participation__c/Transaction__c/npe5__Affiliation__c fully present.

## 6. Data and settings to create in production (not deployable code)
| Item | Sandbox | Prod |
|---|---|---|
| DLE_Email_Dispatch_Config__mdt rows | 19 | 1 |
| Email templates (donor lifecycle) | 20 custom, all with [[Name_For_Email]] | only 4 standard samples |
| TDTM Trigger Handler records | RecurringDonationHandler_TDTM (BeforeInsert;AfterInsert;AfterUpdate, order 3), PaymentTriggerHandler_TDTM (BeforeInsert;BeforeUpdate;AfterUpdate, order 4), OpportunityHandler_TDTM (BeforeInsert;AfterInsert;AfterUpdate, order 5) | none |
| Arifpay_Config__mdt record | 1 | object missing |
| DLE_Engine_Settings__c | no org-level row | no org-level row |
| Scheduled jobs (reminders, birthdays, anniversaries, reports, stale pledged) | see System.schedule lines in SendEmailNotificationBatch | none |
| Apex REST access for the Kentico / ArifPay integration users (class access or permission set) | - | to confirm |

## 7. Order and risks
1. Metadata first: objects, fields, picklist values (including the Missed stage). No behavior change.
2. Classes (new + changed) with the three legacy triggers turned into the deprecated shells, all in one deploy, because the logic moves from the trigger to TDTM at that point.
3. TDTM Trigger Handler records created in the same maintenance window as step 2 (a gap means recurring donations, opportunities and payments are not processed).
4. Dispatch config rows, email templates, ArifPay config, then schedule the jobs. Keep DLE_Engine_Settings__c.Disable_All_Sends__c on until the templates are checked.
5. Prod RecurringDonationTrigger/Handler (113 hook) must be replaced consistently: the TDTM version of the 113 hook is in RecurringDonationHandler_TDTM, so removing the legacy trigger logic and adding the TDTM record happen together or 113 stops generating historic opportunities.
6. Known test issue: GenerateHistoricOppsBatchTest.execute_webAffiliation_createsHistoricOpportunitiesAndCollectsOldest (expected result to be decided).
