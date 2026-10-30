//SFEUCMSD-130
//Close first recurring donation opportunities still Pledged after 24 hours and close their recurring donation
//Hourly schedule: System.schedule('ClosePledgedFirstRDOppsBatch', '0 0 * * * ?', new ClosePledgedFirstRDOppsBatch());
global with sharing class ClosePledgedFirstRDOppsBatch implements Database.Batchable<sObject>, Schedulable {
    //SFEUCMSD-130
    global ClosePledgedFirstRDOppsBatch() {
    }

    //SFEUCMSD-130
    global void execute(SchedulableContext sc) {
        Database.executeBatch(this, 100);
    }

    //SFEUCMSD-130
    global Database.QueryLocator start(Database.BatchableContext BC) {
        Datetime cutoff = Datetime.now().addHours(-24);
        return Database.getQueryLocator([SELECT Id, npe03__Recurring_Donation__c FROM Opportunity WHERE StageName = 'Pledged' AND npe03__Recurring_Donation__c != NULL AND npsp__Recurring_Donation_Installment_Number__c = 1 AND CreatedDate <=: cutoff]);
    }

    //SFEUCMSD-130
    global void execute(Database.BatchableContext BC, List<Opportunity> scope) {
        Map<Id, Id> rdIdByOppId = new Map<Id, Id>();
        for (Opportunity opp : scope) {
            opp.StageName = 'Closed Lost';
            rdIdByOppId.put(opp.Id, opp.npe03__Recurring_Donation__c);
        }

        Set<Id> rdIdsToClose = new Set<Id>();
        List<Database.SaveResult> oppResults = Database.update(scope, false);
        for (Integer i = 0; i < scope.size(); i++) {
            if (oppResults[i].isSuccess()) {
                rdIdsToClose.add(rdIdByOppId.get(scope[i].Id));
            } else {
                System.debug('##ClosePledgedFirstRDOppsBatch opp ' + scope[i].Id + ' errors: ' + oppResults[i].getErrors());
            }
        }

        List<npe03__Recurring_Donation__c> rdsToClose = new List<npe03__Recurring_Donation__c>();
        for (npe03__Recurring_Donation__c rd : [SELECT Id FROM npe03__Recurring_Donation__c WHERE Id IN: rdIdsToClose AND npsp__Status__c != 'Closed']) {
            rd.npsp__Status__c = 'Closed';
            rdsToClose.add(rd);
        }
        List<Database.SaveResult> rdResults = Database.update(rdsToClose, false);
        for (Integer i = 0; i < rdsToClose.size(); i++) {
            if (!rdResults[i].isSuccess()) {
                System.debug('##ClosePledgedFirstRDOppsBatch RD ' + rdsToClose[i].Id + ' errors: ' + rdResults[i].getErrors());
            }
        }
    }

    //SFEUCMSD-130
    global void finish(Database.BatchableContext BC) {
    }
}
