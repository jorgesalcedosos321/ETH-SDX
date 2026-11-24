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
        //SFEUCMSD-130 only active recurring donations get a next opportunity, the closed ones do not
		return Database.getQueryLocator([SELECT Id FROM npe03__Recurring_Donation__c WHERE npsp__Status__c = 'Active']);
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
        
        //SFEUCMSD-147 The Day of Month of each recurring donation sets the day of the next opportunity
        Map<Id, npe03__Recurring_Donation__c> rdsById = new Map<Id, npe03__Recurring_Donation__c>([SELECT Id, npsp__Day_of_Month__c FROM npe03__Recurring_Donation__c WHERE Id IN :rdIds]);

        //Creating rds
        for (npe03__Recurring_Donation__c rd : scope) {
            if (!rdIdsToSkip.contains(rd.Id)) {
                Opportunity baseOpportunity = getLastOpportunityForCurrentMonth(rd.Id, opps);
                if (baseOpportunity != null) {
                	baseOpportunity = createNewOpportunityForNextMonth(baseOpportunity, rdsById.get(rd.Id)?.npsp__Day_of_Month__c); //SFEUCMSD-147
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
        return createNewOpportunityForNextMonth(baseOpportunity, null); //SFEUCMSD-147
    }

    //SFEUCMSD-147 Without a Day of Month the day of the base opportunity is kept, as before
    global Opportunity createNewOpportunityForNextMonth(Opportunity baseOpportunity, String dayOfMonth) {
        Opportunity newOpp = new Opportunity();
        newOpp.AccountId = baseOpportunity.AccountId;
        newOpp.RecordTypeId	= baseOpportunity.RecordTypeId;
        newOpp.Name	= getNewConsecutiveOnNumber(getNewNameBasedOnCloseDate(baseOpportunity.Name, baseOpportunity.CloseDate));
        newOpp.StageName = 'Pledged'; //baseOpportunity.StageName;
        newOpp.Amount = baseOpportunity.Amount;
        //SFEUCMSD-147 The day comes from the Day of Month, so a Last_Day or 31st donation goes back to the 31st after a 30 day month instead of staying on the 30th
        Date nextMonth = baseOpportunity.CloseDate.addMonths(1);
        newOpp.CloseDate = Utils.getInstallmentDate(nextMonth.year(), nextMonth.month(), Utils.getRecurringDayOfMonth(dayOfMonth, baseOpportunity.CloseDate));
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