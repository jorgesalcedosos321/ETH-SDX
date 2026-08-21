global class UpdateOpportunityStatusesBatch implements Database.Stateful, Database.Batchable<sObject>, Database.AllowsCallouts{
    global Set<Id> oppIds;
    global String status;
    public UpdateOpportunityStatusesBatch(Set<Id> oppIds, String status){
        this.oppIds = oppIds;
        this.status = status;
    }

    global void execute(SchedulableContext sc) {
        Database.executeBatch(this);
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([SELECT Id, StageName FROM Opportunity WHERE Id IN : oppIds]);
    }
    
    global void execute(Database.BatchableContext BC, List<Opportunity> scope) {
        for (Opportunity pay : scope) {
            pay.StageName = status;
        }
        
        Database.SaveResult[] srList = Database.Update(scope, false);
        for (Database.SaveResult sr : srList) {
            if (sr.isSuccess()) {
                System.debug('UpdateOpportunityStatusesBatch opp success updated.');                    
            } else {
                for(Database.Error err : sr.getErrors()) {
                    System.debug('UpdateOpportunityStatusesBatch The following error has occurred.');                    
                    System.debug(err.getStatusCode() + ': ' + err.getMessage());
                    System.debug('Payment fields that affected this error: ' + err.getFields());
                }
            }
        }
    }  
    
    global void finish(Database.BatchableContext BC) {
        string importJobId = BC.getJobId(); 
        System.abortJob(importJobId);
    }
}