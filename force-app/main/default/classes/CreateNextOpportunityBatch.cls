////RUNNING FOR NEXT MONTH
//System.schedule('CreateNextOpportunityBatch', '0 0 0 1 * ?', new CreateNextOpportunityBatch());
//String cronTime = Utils.getScheduleCronTime(1, 0, 0, 0, 0, false);
//System.schedule('CreateNextOpportunityBatch:' + Utils.getRandomNumber(7) + ' / cronTime: ' + cronTime, cronTime, new CreateNextOpportunityBatch());
global class CreateNextOpportunityBatch implements Database.Batchable<sObject>,Schedulable, Database.Stateful{
	global void execute(SchedulableContext sc) {
    	Database.executeBatch(this,10); 
	}
    
	global Database.QueryLocator start(Database.BatchableContext BC){
        system.debug('##start CreateNextOpportunityBatch');
		return Database.getQueryLocator([SELECT Id FROM npe03__Recurring_Donation__c WHERE npe03__Open_Ended_Status__c = 'Open']);
    }
    
    global void execute(Database.BatchableContext BC, List<npe03__Recurring_Donation__c> scope){
        Date currentMonth = Date.today();
        Date nextMonth = currentMonth.addMonths(1);
        Set<Id> rdIds = (new Map<Id, npe03__Recurring_Donation__c>(scope).keySet());
        Set<Id> rdIdsToSkip = new Set<Id>();
        List<Opportunity> newOpps = new List<Opportunity>();
        List<Opportunity> opps = [SELECT Id,AccountId,RecordTypeId,Name,StageName,Amount,CloseDate,Type,ContactId,npe03__Recurring_Donation__c,npsp__Primary_Contact__c FROM Opportunity WHERE npe03__Recurring_Donation__c IN : rdIds AND ((CALENDAR_YEAR(CloseDate) =: currentMonth.Year() AND CALENDAR_MONTH(CloseDate) =: currentMonth.Month()) OR (CALENDAR_YEAR(CloseDate) =: nextMonth.Year() AND CALENDAR_MONTH(CloseDate) =: nextMonth.Month()))];
        
        for (Opportunity oppToCheck : opps) {
            if (oppToCheck.StageName == 'Closed Lost') {
                //Closed Lost are not considering on the process
                if (oppToCheck.CloseDate.Month() == currentMonth.Month() && oppToCheck.CloseDate.Year() == currentMonth.Year()) {
                    rdIdsToSkip.add(oppToCheck.npe03__Recurring_Donation__c);
                }
            }
            if (oppToCheck.StageName <> 'Closed Lost' && !rdIdsToSkip.contains(oppToCheck.npe03__Recurring_Donation__c)) {
                //Already created in the process
                if (oppToCheck.CloseDate.Month() == nextMonth.Month() && oppToCheck.CloseDate.Year() == nextMonth.Year()) {
                	rdIdsToSkip.add(oppToCheck.npe03__Recurring_Donation__c);
                }
            }
        }
        
        //Creating rds
        for (npe03__Recurring_Donation__c rd : scope) {
            if (!rdIdsToSkip.contains(rd.Id)) {
                Opportunity baseOpportunity = getLastOpportunityForCurrentMonth(rd.Id, opps);
                if (baseOpportunity != null) {
                	baseOpportunity = createNewOpportunityForNextMonth(baseOpportunity);
                    newOpps.add(baseOpportunity);
                }
            }
        }
        
        if (newOpps.size() > 0) {
         	INSERT newOpps;    
        }
    }
    
    global Opportunity getLastOpportunityForCurrentMonth(Id rdId, List<Opportunity> opps) {
        Date currentMonth = Date.today();
        for (Opportunity opp : opps) {
            if (opp.npe03__Recurring_Donation__c == rdId && opp.CloseDate.Month() == currentMonth.Month() && opp.CloseDate.Year() == currentMonth.Year()) {
                return opp;
            }
        }
        return null;
    }
        
    global Opportunity createNewOpportunityForNextMonth(Opportunity baseOpportunity) {
        Opportunity newOpp = new Opportunity();
        newOpp.AccountId = baseOpportunity.AccountId;
        newOpp.RecordTypeId	= baseOpportunity.RecordTypeId;
        newOpp.Name	= getNewConsecutiveOnNumber(getNewNameBasedOnCloseDate(baseOpportunity.Name, baseOpportunity.CloseDate));
        newOpp.StageName = 'Pledged'; //baseOpportunity.StageName;
        newOpp.Amount = baseOpportunity.Amount;
        newOpp.CloseDate = baseOpportunity.CloseDate.addMonths(1);
        newOpp.Type = baseOpportunity.Type;
        newOpp.ContactId = baseOpportunity.ContactId;
        newOpp.npe03__Recurring_Donation__c = baseOpportunity.npe03__Recurring_Donation__c;
        newOpp.npsp__Primary_Contact__c = baseOpportunity.npsp__Primary_Contact__c;
        return newOpp; 
    }
    
    global String getNewNameBasedOnCloseDate(String name, Date closeDate) {
        Integer index = name.lastIndexOf(' ');
        if (index >= 0) {
            String dateString = name.substring(index + 1);
            try {
                system.debug('converting dateString:' + dateString);
                Date newDate = date.parse(dateString).addMonths(1);
                Datetime dateToFormat = dateTime.NewInstance(newDate.Year(),newDate.Month(),newDate.Day());
                return name.replace(dateString, dateToFormat.format('dd/MM/YYYY'));
            } catch(Exception ex) {
                system.debug('error on getNewNameBasedOnCloseDate');
            }
        }
		return name;
    }
    
    global String getNewConsecutiveOnNumber(String name) {
        Integer index = name.lastIndexOf('(');
        if (index >= 0) {
            String getNumber = name.substring(index + 1);
            System.debug('###getNumber:' + getNumber);
            Integer nextP = getNumber.lastIndexOf(')');
            System.debug('###nextP:' + nextP);
            if (nextP >= 0) {
            	getNumber = getNumber.substring(0, nextP);
            	System.debug('###getNumber:' + getNumber);
                try {
                    Integer nextNumber = Integer.valueOf(getNumber) + 1;
                    System.debug('###nextNumber:' + nextNumber);
                    name = name.replace('(' + getNumber + ')', '(' + nextNumber + ')');
				}catch(Exception ex) {
                    system.debug('error on getNewConsecutiveOnNumber');
                }
            }
        }
		return name;
    }

	global void finish(Database.BatchableContext BC){
        system.debug('##finish CreateNextOpportunityBatch');
    }
}