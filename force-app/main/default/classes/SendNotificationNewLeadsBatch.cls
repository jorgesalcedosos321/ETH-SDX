//SendNotificationNewLeadsBatch snl = new SendNotificationNewLeadsBatch();
//snl.daysBefore = -7;
//System.schedule('SendNotificationNewLeadsBatch', '0 0 0 * * ?', snl);
global class SendNotificationNewLeadsBatch implements Database.Batchable<sObject>,Schedulable, Database.Stateful{
    global Integer daysBefore = -7;

	global void execute(SchedulableContext sc) {
    	Database.executeBatch(this,9); 
	}
    
	global Database.QueryLocator start(Database.BatchableContext BC){
        system.debug('##start SendNotificationNewLeadsBatch');
		Datetime SevenDaysBefore = Datetime.now().addDays(daysBefore);
		return Database.getQueryLocator([SELECT Id, OwnerId FROM Lead WHERE Status = 'New' AND CreatedDate <: SevenDaysBefore]);
    }
    
    global void execute(Database.BatchableContext BC, List<Lead> scope){
        List<Task> ts = new List<Task>();
        for (Lead leadToCheck : scope) {
            Task newTask = new Task();
            newTask.OwnerId = leadToCheck.OwnerId;
            //newTask.WhatId = leadToCheck.Id;
            newTask.WhoId = leadToCheck.Id;
            newTask.Subject = 'Please check this lead that has more than 7 days created and status "New"';
            ts.add(newTask);
        }
        
        if (ts.size() > 0) {
         	INSERT ts;    
        }
    }

	global void finish(Database.BatchableContext BC){
        system.debug('##finish SendNotificationNewLeadsBatch');
    }
}