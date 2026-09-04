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
//Run once to check daily for one-time donations created one month ago:
//System.schedule('ONE_TIME_DONORS_LE - Daily', '0 0 0 * * ?', new SendEmailNotificationBatch(Utils.ONE_TIME_DONORS_LE));
global class SendEmailNotificationBatch implements Database.Batchable<sObject>, Schedulable {
    global Datetime testStartDate = NULL;
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
            Datetime currentYearStart = testStartDate != null ? testStartDate.addDays(1) : Datetime.newInstance(
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
                SELECT Id, npe03__Contact__c
                FROM npe03__Recurring_Donation__c
                WHERE npe03__Contact__c != null
                AND npe03__Contact__r.Email != null
                AND Id IN (
                    SELECT npe03__Recurring_Donation__c
                    FROM Opportunity
                    WHERE StageName = 'Closed Won'
                )
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
        } else if (templateKey == Utils.ONE_TIME_DONORS_LE) {
            List<Datetime> anniversaryWindow = oneMonthAnniversaryWindow(today);
            Datetime donationDateStart = anniversaryWindow[0];
            Datetime donationDateEnd = anniversaryWindow[1];

            if (testStartDate != NULL) {
                donationDateStart = testStartDate.addMonths(-1);
                donationDateEnd = testStartDate.addDays(1);
            }

            return Database.getQueryLocator([
                SELECT Id, ContactId, npsp__Primary_Contact__c
                FROM Opportunity
                WHERE Donation_Type__c = 'One-time Donation'
                AND CreatedDate >= :donationDateStart
                AND CreatedDate < :donationDateEnd
                AND (ContactId != null OR npsp__Primary_Contact__c != null)
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
        System.debug('###Template Key: ' + templateKey);
        System.debug('###scope: ' + scope);
        System.debug('###testStartDate: ' + testStartDate);

        Map<Id, Id> targets = buildTargets(templateKey, scope, testStartDate);
        System.debug('###targets: ' + targets);

        List<Task> tsk = new List<Task>();
        if (!targets.isEmpty()) {
            if (templateKey == Utils.LOYALTY_CALL_AFTER_6) {
                for (Id contactId : targets.keySet()) {
                    Id opportunityId = targets.get(contactId);
                    Task t1 = Utils.createNotification('Loyalty call after 6 payments', 'Call', contactId, opportunityId, Date.today(), Date.today(), UserInfo.getUserId(), NULL, NULL);
                    tsk.add(t1);
                }
                System.debug(tsk.size() + ' task created');
            } else {
                Set<Id> accepted = DLE_EmailDispatchService.sendEmail(templateKey, targets);
                System.debug(accepted.size() + ' of ' + targets.size() + ' emails accepted');
            }
        }

        if (!tsk.isEmpty()) {
            Database.SaveResult[] srs = Database.insert(tsk, false);
            for (Database.SaveResult sr : srs) {
                if (!sr.isSuccess()) {
                    for (Database.Error err : sr.getErrors()) {
                        System.debug('###SendEmailNotificationBatch Error creating task: ' + err.getMessage());
                    }
                }
            }
        }
    }

    @TestVisible
    private static Map<Id, Id> buildTargets(String selectedTemplateKey, List<sObject> scope, Datetime testStartDate) {
        Map<Id, Id> targets = new Map<Id, Id>();

        if (
            selectedTemplateKey == Utils.REMINDER_1 ||
            selectedTemplateKey == Utils.REMINDER_2 ||
            selectedTemplateKey == Utils.REMINDER_3
        ) {
            targets.putAll(buildReminderTargets(selectedTemplateKey, scope, testStartDate != null ? testStartDate.date() : Date.today()));
        } else if (selectedTemplateKey == Utils.LOYALTY_CALL_AFTER_6) {
            targets.putAll(buildLoyaltyTargets(scope));
        } else if (selectedTemplateKey == Utils.ANNIVERSARY_EMAIL_1) {
            targets.putAll(buildSponsorshipAnniversaryTargets(scope));
        } else if (selectedTemplateKey == Utils.ONE_TIME_DONORS_LE) {
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

    @TestVisible
    private static List<Datetime> oneMonthAnniversaryWindow(Date runDate) {
        Date previousMonthEnd = runDate.toStartOfMonth().addDays(-1);
        Date currentMonthEnd = runDate.addMonths(1).toStartOfMonth().addDays(-1);
        Date startDate;
        Date endDate;

        if (
            runDate == currentMonthEnd &&
            runDate.day() <= previousMonthEnd.day()
        ) {
            startDate = Date.newInstance(
                previousMonthEnd.year(),
                previousMonthEnd.month(),
                runDate.day()
            );
            endDate = previousMonthEnd.addDays(1);
        } else if (runDate.day() <= previousMonthEnd.day()) {
            startDate = Date.newInstance(
                previousMonthEnd.year(),
                previousMonthEnd.month(),
                runDate.day()
            );
            endDate = startDate.addDays(1);
        } else {
            // The prior month has no matching day. Its final dates were already
            // handled on the shorter following month's final day.
            startDate = runDate;
            endDate = runDate;
        }

        return new List<Datetime>{
            Datetime.newInstance(startDate, Time.newInstance(0, 0, 0, 0)),
            Datetime.newInstance(endDate, Time.newInstance(0, 0, 0, 0))
        };
    }

    @TestVisible
    private static Map<Id, Id> buildLoyaltyTargets(List<sObject> scope) {
        Map<Id, Id> contactsByRecurringDonation = new Map<Id, Id>();
        for (sObject record : scope) {
            npe03__Recurring_Donation__c recurringDonation =
                (npe03__Recurring_Donation__c) record;
            if (recurringDonation.npe03__Contact__c != null) {
                contactsByRecurringDonation.put(
                    recurringDonation.Id,
                    recurringDonation.npe03__Contact__c
                );
            }
        }
        if (contactsByRecurringDonation.isEmpty()) {
            return new Map<Id, Id>();
        }

        Map<Id, List<Opportunity>> opportunitiesByRecurringDonation =
            new Map<Id, List<Opportunity>>();
        Set<Id> recurringDonationIds = contactsByRecurringDonation.keySet();
        for (Opportunity opportunity : [
            SELECT Id, StageName, npe03__Recurring_Donation__c,
                npsp__Recurring_Donation_Installment_Number__c
            FROM Opportunity
            WHERE npe03__Recurring_Donation__c IN :recurringDonationIds
            AND StageName IN ('Closed Won', 'Closed Lost', 'Declined', 'Missed')
            ORDER BY npe03__Recurring_Donation__c,
                npsp__Recurring_Donation_Installment_Number__c ASC
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
            Opportunity sixthPayment = getSixthConsecutivePayment(
                opportunitiesByRecurringDonation.get(recurringDonationId)
            );
            if (sixthPayment != null) {
                targets.put(
                    contactsByRecurringDonation.get(recurringDonationId),
                    sixthPayment.Id
                );
            }
        }
        return targets;
    }

    @TestVisible
    private static Opportunity getSixthConsecutivePayment(
        List<Opportunity> opportunities
    ) {
        if (opportunities.size() != 6) {
            return null;
        }
        Decimal firstInstallment =
            opportunities[0].npsp__Recurring_Donation_Installment_Number__c;
        if (firstInstallment == null) {
            return null;
        }
        for (Integer index = 0; index < opportunities.size(); index++) {
            Opportunity opportunity = opportunities[index];
            if (
                opportunity.StageName != 'Closed Won' ||
                opportunity.npsp__Recurring_Donation_Installment_Number__c !=
                    firstInstallment + index
            ) {
                return null;
            }
        }
        return opportunities[5];
    }

    //SFESWCSD-85 case 8
    //SFESWCSD-85 case 9
    //SFESWCSD-85 case 10
    @TestVisible
    private static Map<Id, Id> buildReminderTargets(
        String selectedTemplateKey,
        List<sObject> scope,
        Date testStartDate
    ) {
        Integer requiredMisses = selectedTemplateKey == Utils.REMINDER_1
            ? 1
            : selectedTemplateKey == Utils.REMINDER_2 ? 2 : 3;
        System.debug('###requiredMisses: ' + requiredMisses);
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
        System.debug('###contactsByRecurringDonation: ' + contactsByRecurringDonation);

        Date dateToCheck = testStartDate != null ? testStartDate : Date.Today();
        Set<Id> recurringDonationIds = contactsByRecurringDonation.keySet();
        Map<Id, List<Opportunity>> opportunitiesByRecurringDonation =
            new Map<Id, List<Opportunity>>();
        for (Opportunity opportunity : [
            SELECT Id, StageName, CloseDate,
                npe03__Recurring_Donation__c,
                npsp__Recurring_Donation_Installment_Number__c
            FROM Opportunity
            WHERE npe03__Recurring_Donation__c IN :recurringDonationIds
            AND CloseDate <= :dateToCheck
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
        System.debug('###opportunitiesByRecurringDonation: ' + opportunitiesByRecurringDonation);

        Map<Id, Id> targets = new Map<Id, Id>();
        for (Id recurringDonationId : opportunitiesByRecurringDonation.keySet()) {
            Opportunity latestMissedOpportunity = getReminderOpportunity(
                opportunitiesByRecurringDonation.get(recurringDonationId),
                requiredMisses,
                dateToCheck
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
            Date expectedMissMonth = runDate.addMonths(
                -(consecutiveMisses + 1)
            );
            System.debug('###expectedMissMonth: ' + expectedMissMonth);
            System.debug('###opportunity.CloseDate: ' + opportunity.CloseDate);
            System.debug('###opportunity.npsp__Recurring_Donation_Installment_Number__c: ' + opportunity.npsp__Recurring_Donation_Installment_Number__c);
            System.debug('###opportunity.npe03__Recurring_Donation__c: ' + opportunity.npe03__Recurring_Donation__c);
            if (
                opportunity.CloseDate.year() != expectedMissMonth.year() ||
                opportunity.CloseDate.month() != expectedMissMonth.month()
            ) {
                return null;
            }
            if (latestMissedOpportunity == null) {
                latestMissedOpportunity = opportunity;
            }
            consecutiveMisses++;
        }
        System.debug('###consecutiveMisses: ' + consecutiveMisses);
        return consecutiveMisses == requiredMisses
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
