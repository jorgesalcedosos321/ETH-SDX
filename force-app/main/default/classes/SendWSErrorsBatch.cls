//Close opportunities that have payment attempts higher than 3 and are not paid yet
//String cronTime = Utils.getScheduleCronTime(0, 9, 0, 0, 0, false);
//System.schedule('SendWSErrorsBatch', cronTime, new SendWSErrorsBatch());
global class SendWSErrorsBatch implements Database.Batchable<sObject>, Schedulable, Database.Stateful{
    global SendWSErrorsBatch(){
    }
    
    global void execute(SchedulableContext sc) {
        Database.executeBatch(this,9);
    }

    global Database.QueryLocator start(Database.BatchableContext BC){
        System.debug('##start SendWSErrorsBatch');
        return Database.getQueryLocator([SELECT Id, Json__c, Errors__c FROM Transaction__c WHERE Has_Errors__c = true AND Fixed__c = false]);
    }

    global void execute(Database.BatchableContext BC, List<Transaction__c> scope){
        System.debug('##execute SendWSErrorsBatch');
        List<String> errorsCollection = new List<String>();
        for (Transaction__c tx : scope) {
            errorsCollection.add('Json To check:' + tx.Json__c + '<br>Error caused:' + tx.Errors__c); 
        }
        
        if (!errorsCollection.isEmpty()) {
            String body = String.join(errorsCollection, '<br>');
            Utils.sendEmailByParams('Errors for WS', body, null, null, Utils.usersToNotifyWSErrors, null, null);
        }
    }

    global void finish(Database.BatchableContext BC){
    }
}