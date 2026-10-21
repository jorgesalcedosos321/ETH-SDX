/**
 * Created by salcedJ on 07/10/2026 based on Angello codeBase.
 */
//SFESWCSD-113
// Database.executeBatch(new GenerateHistoricOppsBatch(new Set<Id>{'a09dP00000LlsvJQAR'}), 20);
global class GenerateHistoricOppsBatch implements Database.Batchable<SObject>, Database.Stateful {

    //SFESWCSD-113 Number of recurring donations processed in every execution of the batch
    public static final Integer BATCH_SIZE = 10;

    //SFESWCSD-113 Stage given to the new opportunities when no stage name is sent
    public static final String DEFAULT_STAGE_NAME = 'Pledged';

    private Set<Id> recordIds;
    private Set<Id> webRecurringDonationIds;
    //SFESWCSD-113
    private String stageName;

    global GenerateHistoricOppsBatch(Set<Id> ids){
        this(ids, new Set<Id>());
    }

    global GenerateHistoricOppsBatch(Set<Id> ids, Set<Id> webIds){
        this(ids, webIds, DEFAULT_STAGE_NAME);
    }

    //SFESWCSD-113 A blank stage name falls back to the default one
    global GenerateHistoricOppsBatch(Set<Id> ids, Set<Id> webIds, String stageName){
        recordIds = ids == null ? new Set<Id>() : ids;
        webRecurringDonationIds = webIds == null ? new Set<Id>() : webIds;
        this.stageName = String.isBlank(stageName) ? DEFAULT_STAGE_NAME : stageName;
    }

    //SFESWCSD-113 Runs the batch with the fixed number of recurring donations per round
    global static Id run(Set<Id> ids, Set<Id> webIds) {
        return run(ids, webIds, DEFAULT_STAGE_NAME);
    }

    //SFESWCSD-113
    global static Id run(Set<Id> ids, Set<Id> webIds, String stageName) {
        return Database.executeBatch(new GenerateHistoricOppsBatch(ids, webIds, stageName), BATCH_SIZE);
    }

    //SFESWCSD-113 When no ids are sent every recurring donation is checked
    global Database.QueryLocator start(Database.BatchableContext bc) {
        if (recordIds.isEmpty()) {
            System.debug('####GenerateHistoricOppsBatch start recordIds is empty, processing all recurring donations');
            return Database.getQueryLocator([SELECT Id FROM npe03__Recurring_Donation__c ORDER BY Id]);
        }
        System.debug('####GenerateHistoricOppsBatch start recordIds is not empty, processing ' + recordIds.size() + ' recurring donations');
        return Database.getQueryLocator([SELECT Id FROM npe03__Recurring_Donation__c WHERE Id IN :recordIds ORDER BY Id]);
    }

    //SFESWCSD-113
    global void execute(Database.BatchableContext bc, List<SObject> records) {
        System.debug('####GenerateHistoricOppsBatch execute processing ' + records.size() + ' recurring donations');
        List<Id> scope = new List<Id>();
        for (SObject record : records) {
            scope.add(record.Id);
        }
        execute(bc, scope);
    }

    public void execute(Database.BatchableContext bc, List<Id> scope) {
        System.debug('####GenerateHistoricOppsBatch execute processing ' + scope.size() + ' recurring donations');
        Map<Id, npe03__Recurring_Donation__c> numOfMonthsMap = new Map<Id,npe03__Recurring_Donation__c>();
        Map<Id, Opportunity> oppsByRDMap = new Map<Id,Opportunity>();
        Set<Id> rdIds = new Set<Id>();
        for(npe03__Recurring_Donation__c rd : [SELECT Id, npe03__Contact__c, npe03__Organization__c, npe03__Date_Established__c, npsp__Day_of_Month__c, npe03__Next_Payment_Date__c, npsp__StartDate__c, npe03__Recurring_Donation_Campaign__c FROM npe03__Recurring_Donation__c WHERE Id IN: scope AND npe03__Date_Established__c != NULL AND npe03__Next_Payment_Date__c != NULL]){
            // if (rd.npe03__Date_Established__c == null || rd.npe03__Next_Payment_Date__c == null) {
            //     System.debug(LoggingLevel.WARN, '### GenerateHistoricOppsBatch.execute - Not generating historic opportunities because of missing dates. '
            //             + 'RecurringDonationId=' + rd.Id
            //             + ', npe03__Date_Established__c=' + rd.npe03__Date_Established__c
            //             + ', npe03__Next_Payment_Date__c=' + rd.npe03__Next_Payment_Date__c);
            //     continue;
            // }
            Integer numberOfMonths = rd.npe03__Date_Established__c.monthsBetween(rd.npe03__Next_Payment_Date__c);
            System.debug('####GenerateHistoricOppsBatch execute numberOfMonths: ' + numberOfMonths);
            if(numberOfMonths>0) {
                numOfMonthsMap.put(rd.Id, rd);
            }
        }

        List<Opportunity> opps = [SELECT Id, AccountId, Amount, CampaignId, CloseDate, ContactId, ContractId, Name, OwnerId, RecordTypeId, StageName, npe01__Contact_Id_for_Role__c, npsp__Primary_Contact__c, npe03__Recurring_Donation__c FROM Opportunity WHERE npe03__Recurring_Donation__c IN: numOfMonthsMap.keySet()];
        //, npe03__Recurring_Donation__r.npe03__Date_Established__c, npe03__Recurring_Donation__r.npsp__Day_of_Month__c, npe03__Recurring_Donation__r.npe03__Next_Payment_Date__c, npe03__Recurring_Donation__r.npsp__StartDate__c

        for (Id recordId : numOfMonthsMap.keySet()) {
            for(Opportunity opp : opps){
                if(recordId == opp.npe03__Recurring_Donation__c){
                    if(!oppsByRDMap.containsKey(recordId)){
                        oppsByRDMap.put(recordId, opp);
                    }
                }
            }
        }

        String keyWord = 'Donation';
        List<Opportunity> newOpps = new List<Opportunity>();
        for (Id recordId : numOfMonthsMap.keySet()) {
            npe03__Recurring_Donation__c rdToCheck = numOfMonthsMap.get(recordId);
            Integer numberOfMonths = rdToCheck.npe03__Date_Established__c.monthsBetween(rdToCheck.npe03__Next_Payment_Date__c);
            Integer dayOfMonth = String.isNotBlank(rdToCheck.npsp__Day_of_Month__c) && rdToCheck.npsp__Day_of_Month__c.isNumeric() ? Integer.valueOf(rdToCheck.npsp__Day_of_Month__c) : rdToCheck.npe03__Date_Established__c.day();
            for(Integer i=1; i <= numberOfMonths; i++){
                Boolean opportunityExists = existOpportunity(rdToCheck, opps, i);

                if (opportunityExists) {
                    System.debug(LoggingLevel.INFO, '###GenerateHistoricOppsBatch.execute - Opportunity already exists for Recurring Donation Id: ' + recordId + ' and month: ' + i);
                    continue;
                }

                Opportunity opp = new Opportunity();
                opp = oppsByRDMap.get(recordId).clone(false, false, false, false);
                opp.StageName = stageName; //SFESWCSD-113
                opp.CloseDate = rdToCheck.npe03__Date_Established__c.addMonths(i); //oppsByRDMap.get(recordId).CloseDate.addMonths(i);
                opp.CloseDate = Date.newInstance(opp.CloseDate.year(), opp.CloseDate.month(), dayOfMonth);
                opp.Name = oppsByRDMap.get(recordId).Name.substringBefore(keyWord) + ' ' + keyWord + ' ' + Datetime.newInstance(opp.CloseDate.year(),opp.CloseDate.month(),opp.CloseDate.day()).format('yyyy-MM-dd');
                System.debug('####Opp ' + opp);
                newOpps.add(opp);
            }
        }
        if(newOpps.size()>0){
            Database.SaveResult[] results = Database.insert(newOpps, false);
            for (Database.SaveResult sr : results) {
                if (!sr.isSuccess()) {
                    for (Database.Error err : sr.getErrors()) {
                        System.debug(LoggingLevel.ERROR, '###GenerateHistoricOppsBatch.execute - Error inserting historic opportunity: ' + err.getMessage());
                    }
                }else{
                    System.debug(LoggingLevel.INFO, '###GenerateHistoricOppsBatch.execute - Historic opportunity inserted successfully. Id: ' + sr.getId());
                }
            }
        }

        markOldestOpportunityAsCollected(scope);
    }

    private boolean existOpportunity(npe03__Recurring_Donation__c rd, List<Opportunity> opps, Integer monthOffset) {
        Date targetCloseDate = rd.npe03__Date_Established__c.addMonths(monthOffset);
        for (Opportunity opp : opps) {
            if (opp.npe03__Recurring_Donation__c == rd.Id && opp.CloseDate.month() == targetCloseDate.month() && opp.CloseDate.year() == targetCloseDate.year()) {
                return true;
            }
        }
        return false;
    }
    /**
     * Las afiliaciones procesadas desde la web se reconocen porque el documento
     * del beneficiario difiere del documento del tarjeta habiente.
     */
    private void markOldestOpportunityAsCollected(List<Id> scope) {
        Set<Id> recurringDonationIdsToProcess = new Set<Id>();
        for (Id recurringDonationId : scope) {
            if (webRecurringDonationIds.contains(recurringDonationId)) {
                recurringDonationIdsToProcess.add(recurringDonationId);
            }
        }

        if (recurringDonationIdsToProcess.isEmpty()) {
            return;
        }

        Map<Id, Opportunity> oldestOpportunityByRecurringDonation = new Map<Id, Opportunity>();
        for (Opportunity opportunity : [
                SELECT Id, npe03__Recurring_Donation__c, CloseDate, StageName
                FROM Opportunity
                WHERE npe03__Recurring_Donation__c IN :recurringDonationIdsToProcess AND StageName != 'Closed Won'
                ORDER BY CloseDate ASC, CreatedDate ASC, Id ASC
        ]) {
            if (!oldestOpportunityByRecurringDonation.containsKey(opportunity.npe03__Recurring_Donation__c)) {
                oldestOpportunityByRecurringDonation.put(opportunity.npe03__Recurring_Donation__c, opportunity);
            }
        }

        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        for (Opportunity opportunity : oldestOpportunityByRecurringDonation.values()) {
            if (opportunity.StageName != 'Closed Won') {
                opportunitiesToUpdate.add(new Opportunity(
                        Id = opportunity.Id,
                        StageName = 'Closed Won'
                ));
            }
        }

        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('ID Batch finished');
    }
}
 