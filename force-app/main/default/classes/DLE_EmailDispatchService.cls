/**
 * Entry point for the Donor Lifecycle Engine.
 *
 * Given an event key (a DLE_Email_Dispatch_Config__mdt DeveloperName) and a map of
 * recipient WhoId -> related WhatId (the WhatId may be null), renders the configured
 * Lightning Email Template and sends it to every eligible recipient.
 *
 * Returns the set of recipient WhoIds for which an email was accepted for delivery.
 * Callers that need the related WhatId can look it up in the map they passed in.
 *
 * Per-instance callers replace the legacy `Utils.sendEmail(...)` with
 * `DLE_EmailDispatchService.sendEmail(...)`.
 *
 * Every recipient handed to Messaging.sendEmail is recorded as a DLE_Email_Log__c row
 * (Sent or Failed). Logging is best-effort - a logging failure never blocks a send -
 * and can be switched off by checking DLE_Engine_Settings__c.Disable_Send_Logging__c.
 *
 * A global kill switch, DLE_Engine_Settings__c.Disable_All_Sends__c, short-circuits sendEmail
 * before any config resolution: it returns an empty set and writes no log rows.
 */
public with sharing class DLE_EmailDispatchService {

    /** Maximum SingleEmailMessages allowed in one Messaging.sendEmail call. */
    @TestVisible
    private static Integer sendChunkSize = 100;

    /**
     * Upper bound on the send-chunk size when an attachment provider is configured.
     * Roughly the per-transaction Visualforce getContentAsPDF() ceiling; the real
     * safeguard is keeping the per-call recipient map small, but this caps heap.
     */
    private static final Integer ATTACHMENT_PROVIDER_CHUNK_CAP = 10;

    /** Every message handed to flush() during a test run, for assertions. */
    @TestVisible
    private static List<Messaging.SingleEmailMessage> dispatchedInTest;

    /** Test seam: when false, no DLE_Email_Log__c rows are built or captured. */
    @TestVisible
    private static Boolean loggingEnabled = true;

    /** During a test run, the rows writeLogs() would have inserted (no DML is issued). */
    @TestVisible
    private static List<DLE_Email_Log__c> loggedInTest;

    /** Config values that describe one dispatch, copied onto every log row it produces. */
    private class LogContext {
        final String eventKey;
        final String templateDevName;
        final String fromAddress;
        final String attachmentProviderClass;

        LogContext(
                String eventKey,
                String templateDevName,
                String fromAddress,
                String attachmentProviderClass
        ) {
            this.eventKey = eventKey;
            this.templateDevName = templateDevName;
            this.fromAddress = fromAddress;
            this.attachmentProviderClass = attachmentProviderClass;
        }
    }

    /** Per-recipient result of Messaging.sendEmail. */
    private class SendOutcome {
        final Boolean success;
        final String error;

        SendOutcome(Boolean success, String error) {
            this.success = success;
            this.error = error;
        }
    }

    /**
     * Render the Lightning Email Template configured for `eventKey` and send it now to every
     * eligible recipient in `targetIdsByWho`.
     *
     * @param eventKey        DeveloperName of an active DLE_Email_Dispatch_Config__mdt row.
     * @param targetIdsByWho  Recipient WhoId (Contact/Lead/User) -> related WhatId merged into
     *                        the template. The WhatId (map value) may be null.
     * @return The recipient WhoIds accepted for delivery by Messaging.sendEmail. WhoId - not
     *         WhatId - because WhatId is optional; look a WhoId's WhatId up in the map you passed.
     *         Empty when: eventKey/map is blank or empty; the global kill switch
     *         (DLE_Engine_Settings__c.Disable_All_Sends__c) is on; the config is missing or
     *         inactive; or the template DeveloperName does not resolve. The returned set can be
     *         smaller than targetIdsByWho.keySet() when recipients are suppressed - that is not
     *         an error.
     * @throws Exception if the config names an Attachment_Provider_Class__c that cannot be
     *         resolved or does not implement DLE_EmailAttachmentProvider - this aborts the whole
     *         dispatch. (A provider that throws for a single recipient skips only that recipient.)
     */
    public static Set<Id> sendEmail(String eventKey, Map<Id, Id> targetIdsByWho) {
        Set<Id> sentWhoIds = new Set<Id>();
        if (String.isBlank(eventKey) || targetIdsByWho == null || targetIdsByWho.isEmpty()) {
            return sentWhoIds;
        }

        // Global kill switch: no config resolution, no send, no log row.
        DLE_Engine_Settings__c settings = DLE_Engine_Settings__c.getInstance();
        if (settings != null && settings.Disable_All_Sends__c == true) {
            return sentWhoIds;
        }

        DLE_EmailDispatchConfig cfg = DLE_EmailDispatchConfigResolver.get(eventKey);
        if (cfg == null || cfg.active != true) {
            return sentWhoIds;
        }

        Id templateId = DLE_EmailTemplateIdResolver.getId(cfg.templateDevName);
        if (templateId == null) {
            return sentWhoIds;
        }

        List<Messaging.EmailFileAttachment> templateAttachments =
                DLE_EmailTemplateAttachmentResolver.resolve(templateId);

        Id oweaId = DLE_OrgWideEmailAddressResolver.resolve(cfg.fromAddress);

        Boolean hasAttachmentProvider = String.isNotBlank(cfg.attachmentProviderClass);
        if (hasAttachmentProvider) {
            // Resolve once up front so a bad class name aborts the whole dispatch
            // loudly rather than silently sending attachment-less emails.
            DLE_EmailAttachmentResolver.provider(cfg.attachmentProviderClass);
        }
        // A provider renders one attachment (often a PDF) per recipient; keep each
        // Messaging.sendEmail call - and its heap - small when one is configured.
        Integer effectiveChunkSize = hasAttachmentProvider
                ? Math.min(sendChunkSize, ATTACHMENT_PROVIDER_CHUNK_CAP)
                : sendChunkSize;

        Map<Id, DLE_EmailRecipientPolicy.Eligibility> eligibilityByWho =
                DLE_EmailRecipientPolicy.evaluateWhoIds(targetIdsByWho.keySet());

        Map<Id, SendOutcome> outcomeByWho = new Map<Id, SendOutcome>();

        List<Messaging.SingleEmailMessage> batch = new List<Messaging.SingleEmailMessage>();
        List<Id> batchWhoIds = new List<Id>();

        for (Id whoId : targetIdsByWho.keySet()) {
            DLE_EmailRecipientPolicy.Eligibility eligibility = eligibilityByWho.get(whoId);
            if (eligibility == null || !eligibility.allowed) {
                continue;
            }

            Messaging.SingleEmailMessage msg = DLE_EmailSender.buildFromTemplate(
                    templateId, whoId, targetIdsByWho.get(whoId), oweaId);
            if (msg == null) {
                continue;
            }
            
            List<Messaging.EmailFileAttachment> files = new List<Messaging.EmailFileAttachment>();
            if (!templateAttachments.isEmpty()) {
                files.addAll(templateAttachments);
            }

            if (hasAttachmentProvider) {
                try {
                    List<Messaging.EmailFileAttachment> providerFiles =
                            DLE_EmailAttachmentResolver.resolve(
                            cfg.attachmentProviderClass, whoId, targetIdsByWho.get(whoId));
                    if (providerFiles != null) {
                        files.addAll(providerFiles);
                    }
                } catch (Exception e) {
                    // Skip just this recipient; writeLogs records it as Failed.
                    outcomeByWho.put(whoId, new SendOutcome(false, 'attachment: ' + e.getMessage()));
                    continue;
                }
            }
            if (!files.isEmpty()) {
                msg.setFileAttachments(files);
            }

            batch.add(msg);
            batchWhoIds.add(whoId);

            if (batch.size() == effectiveChunkSize) {
                flush(batch, batchWhoIds, sentWhoIds, outcomeByWho);
                batch = new List<Messaging.SingleEmailMessage>();
                batchWhoIds = new List<Id>();
            }
        }
        flush(batch, batchWhoIds, sentWhoIds, outcomeByWho);

        writeLogs(
                new LogContext(
                        cfg.developerName,
                        cfg.templateDevName,
                        cfg.fromAddress,
                        cfg.attachmentProviderClass
                ),
                targetIdsByWho,
                outcomeByWho
        );

        return sentWhoIds;
    }

    private static void flush(
            List<Messaging.SingleEmailMessage> msgs,
            List<Id> whoIds,
            Set<Id> sentWhoIds,
            Map<Id, SendOutcome> outcomeByWho
    ) {
        if (msgs.isEmpty()) {
            return;
        }
        if (Test.isRunningTest()) {
            // Email is never actually sent from a test; record what would have gone out
            // and treat each as delivered so callers can assert on the returned ids.
            if (dispatchedInTest == null) {
                dispatchedInTest = new List<Messaging.SingleEmailMessage>();
            }
            dispatchedInTest.addAll(msgs);
            sentWhoIds.addAll(whoIds);
            for (Id whoId : whoIds) {
                outcomeByWho.put(whoId, new SendOutcome(true, null));
            }
            return;
        }
        Messaging.SendEmailResult[] results = Messaging.sendEmail(msgs, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                sentWhoIds.add(whoIds[i]);
                outcomeByWho.put(whoIds[i], new SendOutcome(true, null));
            } else {
                outcomeByWho.put(whoIds[i], new SendOutcome(false, describeErrors(results[i])));
            }
        }
    }

    private static String describeErrors(Messaging.SendEmailResult result) {
        List<String> parts = new List<String>();
        for (Messaging.SendEmailError err : result.getErrors()) {
            parts.add(err.getStatusCode() + ': ' + err.getMessage());
        }
        return String.join(parts, '\n');
    }

    /**
     * One DLE_Email_Log__c row per recipient we handed to Messaging.sendEmail.
     * Best-effort: swallows its own DML errors so logging can never break a send.
     */
    private static void writeLogs(
            LogContext ctx,
            Map<Id, Id> targetIdsByWho,
            Map<Id, SendOutcome> outcomeByWho
    ) {
        if (!loggingEnabled || outcomeByWho.isEmpty()) {
            return;
        }
        DLE_Engine_Settings__c settings = DLE_Engine_Settings__c.getInstance();
        if (settings != null && settings.Disable_Send_Logging__c == true) {
            return;
        }

        List<DLE_Email_Log__c> rows = new List<DLE_Email_Log__c>();
        for (Id whoId : outcomeByWho.keySet()) {
            SendOutcome outcome = outcomeByWho.get(whoId);
            Id whatId = targetIdsByWho.get(whoId);
            rows.add(new DLE_Email_Log__c(
                    Event_Key__c = ctx.eventKey,
                    Template_DeveloperName__c = ctx.templateDevName,
                    From_Address__c = ctx.fromAddress,
                    Attachment_Provider__c = ctx.attachmentProviderClass,
                    Recipient_Id__c = String.valueOf(whoId),
                    Recipient_Type__c = whoId.getSObjectType().getDescribe().getName(),
                    What_Id__c = whatId == null ? null : String.valueOf(whatId),
                    Status__c = outcome.success ? 'Sent' : 'Failed',
                    Error__c = outcome.error
            ));
        }

        if (Test.isRunningTest()) {
            loggedInTest = rows;
            return;
        }
        try {
            Database.insert(rows, false);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'DLE send logging failed: ' + e.getMessage());
        }
    }
}
