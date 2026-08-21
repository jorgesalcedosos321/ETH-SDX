//Close opportunities that have payment attempts higher than 3 and are not paid yet
//String cronTime = Utils.getScheduleCronTime(0, 11, 0, 0, 0, false);
//System.schedule('CloseOppsDefeatedBatch', cronTime, new CloseOppsDefeatedBatch());
global class CloseOppsDefeatedBatch implements Database.Batchable<sObject>, Schedulable, Database.Stateful{
    global Set<Id> paymentIds = new Set<Id>();            
	global Set<Id> opportunityIds = new Set<Id>();            
	
    global CloseOppsDefeatedBatch(){
    }
    
    global void execute(SchedulableContext sc) {
        Database.executeBatch(this,9);
    }

    global Database.QueryLocator start(Database.BatchableContext BC){
        Date yesterdayDate = Date.today().addDays(-1);
        System.debug('##start CloseOppsDefeatedBatch yesterdayDate:' + yesterdayDate);
        return Database.getQueryLocator([SELECT Id, npe01__Opportunity__c, npe01__Opportunity__r.npsp__Recurring_Donation_Installment_Number__c, Status__c FROM npe01__OppPayment__c WHERE npe01__Paid__c = false AND ((npe01__Opportunity__r.npsp__Recurring_Donation_Installment_Number__c > 1 AND Attempts__c >= 3) OR ((npe01__Opportunity__r.npsp__Recurring_Donation_Installment_Number__c = NULL OR npe01__Opportunity__r.npsp__Recurring_Donation_Installment_Number__c = 1) AND npe01__Scheduled_Date__c =: yesterdayDate))  AND npe01__Opportunity__r.StageName = 'Pledged']);
    }

    global void execute(Database.BatchableContext BC, List<npe01__OppPayment__c> scope){
        System.debug('##execute CloseOppsDefeatedBatch scope:' + scope);
        
        for (npe01__OppPayment__c oppPay : scope) {
            opportunityIds.add(oppPay.npe01__Opportunity__c);
            paymentIds.add(oppPay.Id);
        }
        
        System.debug('##execute CloseOppsDefeatedBatch opportunityIds:' + opportunityIds);
        System.debug('##execute CloseOppsDefeatedBatch paymentIds:' + paymentIds);
    }

    global void finish(Database.BatchableContext BC){
        if (!paymentIds.isEmpty()) {
            List<npe01__OppPayment__c> pays = [SELECT Id, Status__c FROM npe01__OppPayment__c WHERE Id IN: paymentIds];        
            for (npe01__OppPayment__c pay : pays) {
                pay.Status__c = 'Failed';
            }
            UPDATE pays;
        }
        if (!opportunityIds.isEmpty()) {
            List<Opportunity> opps = [SELECT Id, StageName, npsp__Recurring_Donation_Installment_Number__c FROM Opportunity WHERE Id IN : opportunityIds];
            for (Opportunity opp : opps) {
                String stageName = opp.npsp__Recurring_Donation_Installment_Number__c == 1 || opp.npsp__Recurring_Donation_Installment_Number__c == NULL ? 'Closed Lost' : 'Declined';
                opp.StageName = stageName;
            }
            UPDATE opps;     
        }    
    }
}