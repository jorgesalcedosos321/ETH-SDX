//SFEUCMSD-147 Moves recurring donation opportunities that rolled into the next month (e.g. July 1st instead of June 30th) back to the last valid day of their month
//SFEUCMSD-147 Usage: preview fixDates(new Set<Id>{rdId}, true), fix fixDates(new Set<Id>{rdId}, false), all donations Database.executeBatch(new FixRecurringOpportunityDatesBatch(null, false), FixRecurringOpportunityDatesBatch.BATCH_SIZE)
public with sharing class FixRecurringOpportunityDatesBatch implements Database.Batchable<SObject>, Database.Stateful {

    //SFEUCMSD-147 Number of recurring donations processed in every execution of the batch
    public static final Integer BATCH_SIZE = 20;

    //SFEUCMSD-147 Only these Day of Month values can roll into the next month, Ethiopia also allows 31
    private static final Set<String> DAYS_THAT_CAN_ROLL_OVER = new Set<String>{ '29', '30', '31', Utils.LAST_DAY_OF_MONTH };

    //SFEUCMSD-147 Date formats used at the end of opportunity names, Ethiopia names use dd/MM/yyyy
    private static final List<String> NAME_DATE_FORMATS = new List<String>{ 'dd/MM/yyyy', 'yyyy-MM-dd' };

    private static final String CLOSED_WON = 'Closed Won';

    private Set<Id> recurringDonationIds;
    private Boolean previewOnly;

    //SFEUCMSD-147 Every fix found or applied by the batch, kept across executions
    public List<DateFix> fixes = new List<DateFix>();

    //SFEUCMSD-147 Without ids every recurring donation with Day of Month 29, 30 or Last_Day is checked, previewOnly finds the fixes without saving them
    public FixRecurringOpportunityDatesBatch(Set<Id> recurringDonationIds, Boolean previewOnly) {
        this.recurringDonationIds = recurringDonationIds == null ? new Set<Id>() : recurringDonationIds;
        this.previewOnly = previewOnly == true;
    }

    //SFEUCMSD-147
    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (recurringDonationIds.isEmpty()) {
            return Database.getQueryLocator([SELECT Id FROM npe03__Recurring_Donation__c WHERE npsp__Day_of_Month__c IN :DAYS_THAT_CAN_ROLL_OVER ORDER BY Id]);
        }
        return Database.getQueryLocator([SELECT Id FROM npe03__Recurring_Donation__c WHERE npsp__Day_of_Month__c IN :DAYS_THAT_CAN_ROLL_OVER AND Id IN :recurringDonationIds ORDER BY Id]);
    }

    //SFEUCMSD-147
    public void execute(Database.BatchableContext bc, List<npe03__Recurring_Donation__c> scope) {
        fixes.addAll(fixDates(new Map<Id, npe03__Recurring_Donation__c>(scope).keySet(), previewOnly));
    }

    //SFEUCMSD-147
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'FixRecurringOpportunityDatesBatch ' + (previewOnly ? 'found ' : 'fixed ') + fixes.size() + ' opportunities: ' + fixes);
    }

    //SFEUCMSD-147 Finds the opportunities of the given recurring donations that rolled into the next month and, unless previewOnly, moves them and their unpaid payments
    public static List<DateFix> fixDates(Set<Id> recurringDonationIds, Boolean previewOnly) {
        List<DateFix> result = new List<DateFix>();
        if (recurringDonationIds == null || recurringDonationIds.isEmpty()) {
            return result;
        }

        Map<Id, npe03__Recurring_Donation__c> donationsById = new Map<Id, npe03__Recurring_Donation__c>([
            SELECT Id, npsp__Day_of_Month__c, npe03__Date_Established__c
            FROM npe03__Recurring_Donation__c
            WHERE Id IN :recurringDonationIds AND npsp__Day_of_Month__c IN :DAYS_THAT_CAN_ROLL_OVER
        ]);
        if (donationsById.isEmpty()) {
            return result;
        }

        Map<Id, List<Opportunity>> opportunitiesByDonationId = new Map<Id, List<Opportunity>>();
        for (Opportunity opportunity : [
            SELECT Id, Name, CloseDate, StageName, npe03__Recurring_Donation__c,
                (SELECT Id, npe01__Paid__c, npe01__Payment_Date__c, npe01__Scheduled_Date__c FROM npe01__OppPayment__r)
            FROM Opportunity
            WHERE npe03__Recurring_Donation__c IN :donationsById.keySet() AND CloseDate != NULL
            ORDER BY npe03__Recurring_Donation__c, CloseDate, CreatedDate
        ]) {
            if (!opportunitiesByDonationId.containsKey(opportunity.npe03__Recurring_Donation__c)) {
                opportunitiesByDonationId.put(opportunity.npe03__Recurring_Donation__c, new List<Opportunity>());
            }
            opportunitiesByDonationId.get(opportunity.npe03__Recurring_Donation__c).add(opportunity);
        }

        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        List<npe01__OppPayment__c> paymentsToUpdate = new List<npe01__OppPayment__c>();
        for (Id donationId : opportunitiesByDonationId.keySet()) {
            npe03__Recurring_Donation__c donation = donationsById.get(donationId);
            Integer dayOfMonth = Utils.getRecurringDayOfMonth(donation.npsp__Day_of_Month__c, donation.npe03__Date_Established__c);
            for (DateFix fix : findFixes(opportunitiesByDonationId.get(donationId), dayOfMonth)) {
                result.add(fix);
                opportunitiesToUpdate.add(new Opportunity(Id = fix.opportunityId, CloseDate = fix.newDate, Name = fix.newName));
                for (Id paymentId : fix.paymentIds) {
                    paymentsToUpdate.add(new npe01__OppPayment__c(Id = paymentId, npe01__Scheduled_Date__c = fix.newDate));
                }
            }
        }

        if (previewOnly == true || opportunitiesToUpdate.isEmpty()) {
            return result;
        }
        update opportunitiesToUpdate;
        if (!paymentsToUpdate.isEmpty()) {
            update paymentsToUpdate;
        }
        return result;
    }

    //SFEUCMSD-147 An opportunity rolled over when it sits on the overflow day of the month after a short one, that previous month has no opportunity and its own month has another one
    @TestVisible
    private static List<DateFix> findFixes(List<Opportunity> opportunities, Integer dayOfMonth) {
        List<DateFix> result = new List<DateFix>();
        if (opportunities == null || dayOfMonth == null) {
            return result;
        }

        Map<Integer, Integer> countByMonth = new Map<Integer, Integer>();
        for (Opportunity opportunity : opportunities) {
            Integer monthKey = getMonthKey(opportunity.CloseDate);
            countByMonth.put(monthKey, (countByMonth.containsKey(monthKey) ? countByMonth.get(monthKey) : 0) + 1);
        }

        for (Opportunity opportunity : opportunities) {
            Date previousMonth = opportunity.CloseDate.toStartOfMonth().addMonths(-1);
            Integer daysInPreviousMonth = Date.daysInMonth(previousMonth.year(), previousMonth.month());
            Integer previousMonthKey = getMonthKey(previousMonth);
            Integer monthKey = getMonthKey(opportunity.CloseDate);
            Boolean isOverflowDay = dayOfMonth > daysInPreviousMonth && opportunity.CloseDate.day() == dayOfMonth - daysInPreviousMonth;
            Boolean previousMonthIsEmpty = !countByMonth.containsKey(previousMonthKey) || countByMonth.get(previousMonthKey) == 0;
            Boolean monthHasAnother = countByMonth.get(monthKey) > 1;
            if (!isOverflowDay || !previousMonthIsEmpty || !monthHasAnother || isCollected(opportunity)) {
                continue;
            }

            DateFix fix = new DateFix();
            fix.opportunityId = opportunity.Id;
            fix.oldName = opportunity.Name;
            fix.oldDate = opportunity.CloseDate;
            fix.newDate = Utils.getInstallmentDate(previousMonth.year(), previousMonth.month(), dayOfMonth);
            fix.newName = replaceNameDate(opportunity.Name, fix.oldDate, fix.newDate);
            for (npe01__OppPayment__c payment : opportunity.npe01__OppPayment__r) {
                if (payment.npe01__Scheduled_Date__c == fix.oldDate) {
                    fix.paymentIds.add(payment.Id);
                }
            }
            result.add(fix);
            countByMonth.put(previousMonthKey, 1);
            countByMonth.put(monthKey, countByMonth.get(monthKey) - 1);
        }
        return result;
    }

    //SFEUCMSD-147 Collected opportunities keep their date, it follows the real payment date
    private static Boolean isCollected(Opportunity opportunity) {
        if (opportunity.StageName == CLOSED_WON) {
            return true;
        }
        for (npe01__OppPayment__c payment : opportunity.npe01__OppPayment__r) {
            if (payment.npe01__Paid__c || payment.npe01__Payment_Date__c != null) {
                return true;
            }
        }
        return false;
    }

    private static Integer getMonthKey(Date value) {
        return value.year() * 12 + value.month();
    }

    //SFEUCMSD-147 A name ending with the old date as dd/MM/yyyy or yyyy-MM-dd gets the new date in the same format, any other name is kept
    @TestVisible
    private static String replaceNameDate(String name, Date oldDate, Date newDate) {
        if (String.isBlank(name)) {
            return name;
        }
        for (String format : NAME_DATE_FORMATS) {
            String oldText = formatDate(oldDate, format);
            if (name.endsWith(oldText)) {
                return name.removeEnd(oldText) + formatDate(newDate, format);
            }
        }
        return name;
    }

    private static String formatDate(Date value, String format) {
        return Datetime.newInstance(value.year(), value.month(), value.day()).format(format);
    }

    //SFEUCMSD-147 One opportunity to move and the unpaid payments that move with it
    public class DateFix {
        public Id opportunityId;
        public String oldName;
        public String newName;
        public Date oldDate;
        public Date newDate;
        public List<Id> paymentIds = new List<Id>();

        public override String toString() {
            return oldName + ' (' + opportunityId + '): ' + oldDate + ' -> ' + newDate + ', payments moved: ' + paymentIds.size();
        }
    }
}
