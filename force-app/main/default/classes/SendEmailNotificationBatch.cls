//SFESWCSD-85 case 6 - Run once to schedule every June 1 at midnight:
//System.schedule('MID_YEAR_REPORT_PDF - June 1', '0 0 0 1 6 ?', new SendEmailNotificationBatch(Utils.MID_YEAR_REPORT_PDF));
//SFESWCSD-85 case 7 - Run once to schedule every December 30 at midnight:
//System.schedule('END_OF_YEAR_REPORT_P - December 30', '0 0 0 30 12 ?', new SendEmailNotificationBatch(Utils.END_OF_YEAR_REPORT_P));
//SFESWCSD-85 case 8 - Run once to check daily at midnight:
//System.schedule('REMINDER_1 - Monthly', '0 0 0 1 * ?', new SendEmailNotificationBatch(Utils.REMINDER_1));
//SFESWCSD-85 case 9 - Run once to check daily at midnight:
//System.schedule('REMINDER_2 - Monthly', '0 0 0 1 * ?', new SendEmailNotificationBatch(Utils.REMINDER_2));
//SFESWCSD-85 case 10 - Run once to check daily at midnight:
//System.schedule('REMINDER_3 - Monthly', '0 0 0 1 * ?', new SendEmailNotificationBatch(Utils.REMINDER_3));
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
            Date currentYearStart = testStartDate != null ? testStartDate.date().addDays(1) : Date.newInstance(today.year(), 1, 1);

            //Changed by Marina excel 07092026
            //npe03__Date_Established__c instead of CreatedDate because we want to send the email on the anniversary of the donation, not when it was created in Salesforce.
            return Database.getQueryLocator([
                SELECT Id, npe03__Date_Established__c, npe03__Contact__c
                FROM npe03__Recurring_Donation__c
                WHERE Donation_Type__c = :ApiConstants.DONATION_SPONSORSHIP
                AND npe03__Contact__c != null
                AND CALENDAR_MONTH(npe03__Date_Established__c) = :today.month()
                AND DAY_IN_MONTH(npe03__Date_Established__c) = :today.day()
                AND npe03__Date_Established__c < :currentYearStart
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
        } else if (templateKey == Utils.ONE_TIME_DONORS_LE) { //SFESWCSD-86
            List<Date> anniversaryWindow = oneMonthAnniversaryWindow(today);
            Date donationDateStart = anniversaryWindow[0];
            Date donationDateEnd = anniversaryWindow[1];

            if (testStartDate != NULL) {
                donationDateStart = testStartDate.date().addMonths(-1);
                donationDateEnd = testStartDate.date().addDays(1);
            }
            System.debug('###donationDateStart: ' + today.addMonths(-1));
            return Database.getQueryLocator([
                SELECT Id, ContactId, npsp__Primary_Contact__c
                FROM Opportunity
                WHERE Donation_Type__c = 'One-time Donation'
                AND Transaction_Date__c =: today.addMonths(-1)
                AND npe03__Recurring_Donation__c = null
                // AND Transaction_Date__c >= :donationDateStart
                // AND Transaction_Date__c < :donationDateEnd
                AND StageName = 'Closed Won'
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
                AND Donation_Type__c = :ApiConstants.DONATION_SPONSORSHIP //Added by Marina excel 07092026
                AND Id IN (
                    SELECT npe03__Recurring_Donation__c
                    FROM Opportunity
                    WHERE StageName IN ('Declined', 'Missed') //Changed by Marina excel 07092026, 'Closed Lost'
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
            Set<Id> accepted = DLE_EmailDispatchService.sendEmail(templateKey, targets, Utils.buildNameForEmailTokens(targets.keySet())); //SFESWCSD-92
            System.debug(accepted.size() + ' of ' + targets.size() + ' emails accepted');
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
    private static List<Date> oneMonthAnniversaryWindow(Date runDate) {
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

        return new List<Date>{
            startDate,
            endDate
        };
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
        // Months (of the payment's Scheduled Date, or of the opportunity's Close
        // Date when the payment has none) in which a recurring donation has a
        // Missed or Declined opportunity; the last 4 months before the current one.
        Date currentMonthStart = dateToCheck.toStartOfMonth();
        Date windowStart = currentMonthStart.addMonths(-4);
        Map<Id, Set<Integer>> missedMonthsByRecurringDonation = new Map<Id, Set<Integer>>();
        for (npe01__OppPayment__c payment : [
            SELECT npe01__Scheduled_Date__c, npe01__Opportunity__r.CloseDate,
                npe01__Opportunity__r.npe03__Recurring_Donation__c
            FROM npe01__OppPayment__c
            WHERE npe01__Opportunity__r.npe03__Recurring_Donation__c IN :recurringDonationIds
            AND npe01__Opportunity__r.StageName IN ('Declined', 'Missed')
            AND (
                (npe01__Scheduled_Date__c >= :windowStart AND npe01__Scheduled_Date__c < :currentMonthStart)
                OR (
                    npe01__Scheduled_Date__c = null
                    AND npe01__Opportunity__r.CloseDate >= :windowStart
                    AND npe01__Opportunity__r.CloseDate < :currentMonthStart
                )
            )
        ]) {
            Id recurringDonationId =
                payment.npe01__Opportunity__r.npe03__Recurring_Donation__c;
            Date missedDate = payment.npe01__Scheduled_Date__c != null
                ? payment.npe01__Scheduled_Date__c
                : payment.npe01__Opportunity__r.CloseDate;
            if (!missedMonthsByRecurringDonation.containsKey(recurringDonationId)) {
                missedMonthsByRecurringDonation.put(recurringDonationId, new Set<Integer>());
            }
            missedMonthsByRecurringDonation.get(recurringDonationId).add(monthKey(missedDate));
        }
        System.debug('###missedMonthsByRecurringDonation: ' + missedMonthsByRecurringDonation);

        Map<Id, Id> opportunityByRecurringDonation = new Map<Id, Id>();
        for (Id recurringDonationId : missedMonthsByRecurringDonation.keySet()) {
            if (isReminderDue(
                missedMonthsByRecurringDonation.get(recurringDonationId),
                requiredMisses,
                dateToCheck
            )) {
                opportunityByRecurringDonation.put(recurringDonationId, recurringDonationId);
            }
        }
        Map<Id, Id> targets = new Map<Id, Id>();
        if (opportunityByRecurringDonation.isEmpty()) {
            return targets;
        }
        Set<String> alreadySent = alreadySentOpportunityIds(
            selectedTemplateKey,
            new Set<Id>(opportunityByRecurringDonation.values())
        );
        for (Id recurringDonationId : opportunityByRecurringDonation.keySet()) {
            Id opportunityId = opportunityByRecurringDonation.get(recurringDonationId);
            if (!alreadySent.contains(String.valueOf(opportunityId))) {
                //targets.put(contactsByRecurringDonation.get(recurringDonationId), opportunityId);
                targets.put(contactsByRecurringDonation.get(recurringDonationId), recurringDonationId);
            }
        }
        return targets;
    }

    // REMINDER_n is due when the n months before the run month (last month, the
    // month before, ...) are all missed and the month before those is not.
    // 4 missed months in a row: no reminder at all.
    @TestVisible
    private static Boolean isReminderDue(
        Set<Integer> missedMonthKeys,
        Integer requiredMisses,
        Date runDate
    ) {
        for (Integer monthsBack = 1; monthsBack <= requiredMisses; monthsBack++) {
            if (!missedMonthKeys.contains(monthKey(runDate.addMonths(-monthsBack)))) {
                return false;
            }
        }
        return !missedMonthKeys.contains(monthKey(runDate.addMonths(-(requiredMisses + 1))));
    }

    private static Integer monthKey(Date value) {
        return value.year() * 12 + value.month();
    }

    // Reminder payments whose opportunity already got this reminder, so each
    // reminder goes out once per missed payment (and never again on later runs).
    private static Set<String> alreadySentOpportunityIds(String eventKey, Set<Id> opportunityIds) {
        Set<String> sent = new Set<String>();
        Set<String> opportunityIdStrings = new Set<String>();
        for (Id opportunityId : opportunityIds) {
            opportunityIdStrings.add(String.valueOf(opportunityId));
        }
        for (DLE_Email_Log__c log : [
            SELECT What_Id__c
            FROM DLE_Email_Log__c
            WHERE Event_Key__c = :eventKey
            AND Status__c = 'Sent'
            AND What_Id__c IN :opportunityIdStrings
        ]) {
            sent.add(log.What_Id__c);
        }
        return sent;
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
                    recurringDonation.npe03__Date_Established__c < existingCandidate.npe03__Date_Established__c
                )
            ) {
                candidatesByContact.put(
                    recurringDonation.npe03__Contact__c,
                    recurringDonation
                );
            }
        }

        Map<Id, Date> firstSponsorshipDates = new Map<Id, Date>();
        if (!candidatesByContact.isEmpty()) {
            Set<Id> contactIds = candidatesByContact.keySet();
            for (AggregateResult result : [
                SELECT npe03__Contact__c contactId, MIN(npe03__Date_Established__c) firstDate
                FROM npe03__Recurring_Donation__c
                WHERE npe03__Contact__c IN :contactIds
                AND Donation_Type__c = :ApiConstants.DONATION_SPONSORSHIP
                GROUP BY npe03__Contact__c
            ]) {
                firstSponsorshipDates.put(
                    (Id) result.get('contactId'),
                    (Date) result.get('firstDate')
                );
            }
        }

        Map<Id, Id> targets = new Map<Id, Id>();
        for (Id contactId : candidatesByContact.keySet()) {
            npe03__Recurring_Donation__c candidate =
                candidatesByContact.get(contactId);
            if (candidate.npe03__Date_Established__c == firstSponsorshipDates.get(contactId)) {
                targets.put(contactId, candidate.Id);
            }
        }
        return targets;
    }

    global void finish(Database.BatchableContext context) {
    }
}