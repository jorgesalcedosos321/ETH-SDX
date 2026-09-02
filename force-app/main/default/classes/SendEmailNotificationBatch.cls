//SFESWCSD-86
//SFESWCSD-85 case 6 - Run once to schedule every June 1 at midnight:
//System.schedule('MID_YEAR_REPORT_PDF - June 1', '0 0 0 1 6 ?', new SendEmailNotificationBatch(Utils.MID_YEAR_REPORT_PDF));
//SFESWCSD-85 case 7 - Run once to schedule every December 30 at midnight:
//System.schedule('END_OF_YEAR_REPORT_P - December 30', '0 0 0 30 12 ?', new SendEmailNotificationBatch(Utils.END_OF_YEAR_REPORT_P));
//SFESWCSD-85 case 8 - Run once to check daily at midnight:
//System.schedule('REMINDER_1 - Daily', '0 0 0 * * ?', new SendEmailNotificationBatch(Utils.REMINDER_1));
//SFESWCSD-85 case 9 - Run once to check daily at midnight:
//System.schedule('REMINDER_2 - Daily', '0 0 0 * * ?', new SendEmailNotificationBatch(Utils.REMINDER_2));
//SFESWCSD-85 case 10 - Run once to check daily at midnight:
//System.schedule('REMINDER_3 - Daily', '0 0 0 * * ?', new SendEmailNotificationBatch(Utils.REMINDER_3));
global class SendEmailNotificationBatch implements Database.Batchable<sObject>, Schedulable {
    global SendEmailNotificationBatch(String templateKey) {
        this.templateKey = templateKey;
    }
    
    private static final Integer EMAIL_BATCH_SIZE = 10;

    global String templateKey;


    global void execute(SchedulableContext context) {
        Database.executeBatch(new SendEmailNotificationBatch(templateKey), EMAIL_BATCH_SIZE);
    }

    global Database.QueryLocator start(Database.BatchableContext context) {
        Date today = Date.today();

        //SFESWCSD-85 case 4
        if (templateKey == Utils.BIRTHDAY_EMAIL) {
            return Database.getQueryLocator([
                SELECT Id, FirstName, Email
                FROM Contact
                WHERE CALENDAR_MONTH(Birthdate) = :today.month()
                AND DAY_IN_MONTH(Birthdate) = :today.day()
                AND Email != null
            ]);
        //SFESWCSD-85 case 5
        } else if (templateKey == Utils.ANNIVERSARY_EMAIL_1) {
            Datetime currentYearStart = Datetime.newInstance(
                Date.newInstance(today.year(), 1, 1),
                Time.newInstance(0, 0, 0, 0)
            );
            return Database.getQueryLocator([
                SELECT Id, CreatedDate, npe03__Contact__c
                FROM npe03__Recurring_Donation__c
                WHERE Donation_Type__c = :ApiConstants.DONATION_SPONSORSHIP
                AND npe03__Contact__c != null
                AND CALENDAR_MONTH(CreatedDate) = :today.month()
                AND DAY_IN_MONTH(CreatedDate) = :today.day()
                AND CreatedDate < :currentYearStart
            ]);
        //SFESWCSD-85 case 7
        } else if (templateKey == Utils.END_OF_YEAR_REPORT_P) {
            return Database.getQueryLocator([
                SELECT Id, FirstName, Email
                FROM Contact
                WHERE Id IN (
                    SELECT npe03__Contact__c
                    FROM npe03__Recurring_Donation__c
                    WHERE Donation_Type__c = :ApiConstants.DONATION_SPONSORSHIP
                    AND npsp__Status__c = 'Active'
                )
                AND Email != null
            ]);
        } else if (templateKey == Utils.LOYALTY_CALL_AFTER_6) {
            return Database.getQueryLocator([
                SELECT Id, FirstName, Email
                FROM Contact
                WHERE Id IN (SELECT ContactId FROM Opportunity WHERE StageName = 'Closed Lost')
                AND Email != null
            ]);
        //SFESWCSD-85 case 6 ////System.schedule('MID_YEAR_REPORT_PDF - June 1', '0 0 0 1 6 ?', new SendEmailNotificationBatch(Utils.MID_YEAR_REPORT_PDF));
        } else if (templateKey == Utils.MID_YEAR_REPORT_PDF) {
            return Database.getQueryLocator([
                SELECT Id, FirstName, Email
                FROM Contact
                WHERE Id IN (
                    SELECT npe03__Contact__c
                    FROM npe03__Recurring_Donation__c
                    WHERE Donation_Type__c = :ApiConstants.DONATION_SPONSORSHIP
                    AND npsp__Status__c = 'Active'
                )
                AND Email != null
            ]);
        } else if (templateKey == Utils.ONE_TIME_DONORS_TH) {
            Date donationDate = today.addMonths(-1);
            Datetime donationDateStart = Datetime.newInstance(
                donationDate,
                Time.newInstance(0, 0, 0, 0)
            );
            Date donationEndDate = today.addDays(1).day() == 1
                ? donationDate.addMonths(1).toStartOfMonth()
                : donationDate.addDays(1);
            Datetime donationDateEnd = Datetime.newInstance(
                donationEndDate,
                Time.newInstance(0, 0, 0, 0)
            );

            return Database.getQueryLocator([
                SELECT Id, ContactId, npsp__Primary_Contact__c
                FROM Opportunity
                WHERE Donation_Type__c = 'One-time Donation'
                AND StageName = 'Closed Won'
                AND CreatedDate >= :donationDateStart
                AND CreatedDate < :donationDateEnd
                AND (ContactId != null OR npsp__Primary_Contact__c != null)
            ]);
        } else if (templateKey == Utils.ONE_TIME_DONORS_LE) {
            return Database.getQueryLocator([
                SELECT Id, FirstName, Email
                FROM Contact
                WHERE Id IN (SELECT ContactId FROM Opportunity WHERE StageName = 'Closed Lost')
                AND Email != null
            ]);
        //SFESWCSD-85 case 8
        //SFESWCSD-85 case 9
        //SFESWCSD-85 case 10
        } else if (
            templateKey == Utils.REMINDER_1 ||
            templateKey == Utils.REMINDER_2 ||
            templateKey == Utils.REMINDER_3
        ) {
            return Database.getQueryLocator([
                SELECT Id, npe03__Contact__c
                FROM npe03__Recurring_Donation__c
                WHERE npe03__Contact__c != null
                AND Id IN (
                    SELECT npe03__Recurring_Donation__c
                    FROM Opportunity
                    WHERE StageName IN ('Declined', 'Missed', 'Closed Lost')
                )
            ]);
        }
        else {
            throw new IllegalArgumentException('Invalid template key: ' + templateKey);
        }
    }

    global void execute(Database.BatchableContext context, List<sObject> scope) {
        Map<Id, Id> targets = buildTargets(templateKey, scope);

        if (!targets.isEmpty()) {
            Set<Id> accepted = DLE_EmailDispatchService.sendEmail(templateKey, targets);
            System.debug(accepted.size() + ' of ' + targets.size() + ' emails accepted');
        }
    }

    @TestVisible
    private static Map<Id, Id> buildTargets(String selectedTemplateKey, List<sObject> scope) {
        Map<Id, Id> targets = new Map<Id, Id>();

        if (
            selectedTemplateKey == Utils.REMINDER_1 ||
            selectedTemplateKey == Utils.REMINDER_2 ||
            selectedTemplateKey == Utils.REMINDER_3
        ) {
            targets.putAll(buildReminderTargets(selectedTemplateKey, scope));
        } else if (selectedTemplateKey == Utils.ANNIVERSARY_EMAIL_1) {
            targets.putAll(buildSponsorshipAnniversaryTargets(scope));
        } else if (selectedTemplateKey == Utils.ONE_TIME_DONORS_TH) {
            for (sObject record : scope) {
                Opportunity opportunity = (Opportunity) record;
                Id contactId = opportunity.npsp__Primary_Contact__c != null
                    ? opportunity.npsp__Primary_Contact__c
                    : opportunity.ContactId;
                if (contactId != null) {
                    targets.put(contactId, opportunity.Id);
                }
            }
        } else {
            for (sObject record : scope) {
                Contact contact = (Contact) record;
                if (contact.Email != null) {
                    targets.put(contact.Id, null);
                }
            }
        }
        return targets;
    }

    //SFESWCSD-85 case 8
    //SFESWCSD-85 case 9
    //SFESWCSD-85 case 10
    @TestVisible
    private static Map<Id, Id> buildReminderTargets(
        String selectedTemplateKey,
        List<sObject> scope
    ) {
        Integer requiredMisses = selectedTemplateKey == Utils.REMINDER_1
            ? 1
            : selectedTemplateKey == Utils.REMINDER_2 ? 2 : 3;
        Map<Id, Id> contactsByRecurringDonation = new Map<Id, Id>();
        for (sObject record : scope) {
            npe03__Recurring_Donation__c recurringDonation =
                (npe03__Recurring_Donation__c) record;
            contactsByRecurringDonation.put(
                recurringDonation.Id,
                recurringDonation.npe03__Contact__c
            );
        }
        if (contactsByRecurringDonation.isEmpty()) {
            return new Map<Id, Id>();
        }

        Set<Id> recurringDonationIds = contactsByRecurringDonation.keySet();
        Map<Id, List<Opportunity>> opportunitiesByRecurringDonation =
            new Map<Id, List<Opportunity>>();
        for (Opportunity opportunity : [
            SELECT Id, StageName, CloseDate,
                npe03__Recurring_Donation__c,
                npsp__Recurring_Donation_Installment_Number__c
            FROM Opportunity
            WHERE npe03__Recurring_Donation__c IN :recurringDonationIds
            AND CloseDate <= :Date.today()
            ORDER BY npe03__Recurring_Donation__c,
                npsp__Recurring_Donation_Installment_Number__c DESC,
                CloseDate DESC
        ]) {
            if (!opportunitiesByRecurringDonation.containsKey(
                opportunity.npe03__Recurring_Donation__c
            )) {
                opportunitiesByRecurringDonation.put(
                    opportunity.npe03__Recurring_Donation__c,
                    new List<Opportunity>()
                );
            }
            opportunitiesByRecurringDonation.get(
                opportunity.npe03__Recurring_Donation__c
            ).add(opportunity);
        }

        Map<Id, Id> targets = new Map<Id, Id>();
        for (Id recurringDonationId : opportunitiesByRecurringDonation.keySet()) {
            Opportunity latestMissedOpportunity = getReminderOpportunity(
                opportunitiesByRecurringDonation.get(recurringDonationId),
                requiredMisses,
                Date.today()
            );
            if (latestMissedOpportunity != null) {
                targets.put(
                    contactsByRecurringDonation.get(recurringDonationId),
                    latestMissedOpportunity.Id
                );
            }
        }
        return targets;
    }

    @TestVisible
    private static Opportunity getReminderOpportunity(
        List<Opportunity> opportunities,
        Integer requiredMisses,
        Date runDate
    ) {
        Set<String> missedStages = new Set<String>{
            'Declined',
            'Missed',
            'Closed Lost'
        };
        Integer consecutiveMisses = 0;
        Opportunity latestMissedOpportunity;
        for (Opportunity opportunity : opportunities) {
            if (!missedStages.contains(opportunity.StageName)) {
                break;
            }
            if (latestMissedOpportunity == null) {
                latestMissedOpportunity = opportunity;
            }
            consecutiveMisses++;
        }
        return consecutiveMisses == requiredMisses &&
            latestMissedOpportunity.CloseDate.addMonths(1) == runDate
            ? latestMissedOpportunity
            : null;
    }

    //SFESWCSD-85 case 5
    @TestVisible
    private static Map<Id, Id> buildSponsorshipAnniversaryTargets(
        List<sObject> scope
    ) {
        Map<Id, npe03__Recurring_Donation__c> candidatesByContact =
            new Map<Id, npe03__Recurring_Donation__c>();
        for (sObject record : scope) {
            npe03__Recurring_Donation__c recurringDonation =
                (npe03__Recurring_Donation__c) record;
            npe03__Recurring_Donation__c existingCandidate =
                candidatesByContact.get(recurringDonation.npe03__Contact__c);
            if (
                recurringDonation.npe03__Contact__c != null &&
                (
                    existingCandidate == null ||
                    recurringDonation.CreatedDate < existingCandidate.CreatedDate
                )
            ) {
                candidatesByContact.put(
                    recurringDonation.npe03__Contact__c,
                    recurringDonation
                );
            }
        }

        Map<Id, Datetime> firstSponsorshipDates = new Map<Id, Datetime>();
        if (!candidatesByContact.isEmpty()) {
            Set<Id> contactIds = candidatesByContact.keySet();
            for (AggregateResult result : [
                SELECT npe03__Contact__c contactId, MIN(CreatedDate) firstDate
                FROM npe03__Recurring_Donation__c
                WHERE npe03__Contact__c IN :contactIds
                AND Donation_Type__c = :ApiConstants.DONATION_SPONSORSHIP
                GROUP BY npe03__Contact__c
            ]) {
                firstSponsorshipDates.put(
                    (Id) result.get('contactId'),
                    (Datetime) result.get('firstDate')
                );
            }
        }

        Map<Id, Id> targets = new Map<Id, Id>();
        for (Id contactId : candidatesByContact.keySet()) {
            npe03__Recurring_Donation__c candidate =
                candidatesByContact.get(contactId);
            if (candidate.CreatedDate == firstSponsorshipDates.get(contactId)) {
                targets.put(contactId, candidate.Id);
            }
        }
        return targets;
    }

    global void finish(Database.BatchableContext context) {
    }
}
