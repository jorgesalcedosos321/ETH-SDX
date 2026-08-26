public class PaymentTriggerService implements IPaymentTriggerService {    
    /**
     * Creates an Opportunity Payment.
     */
    //SFESWCSD-92
    public static npe01__OppPayment__c create(
        DonationRequest request,
        Id opportunityId
    ) {
        npe01__OppPayment__c payment =
            buildPayment(
                request,
                opportunityId
            );

        insert payment;
        return payment;
    }

    /**
     * Builds an Opportunity Payment.
     */
    public static npe01__OppPayment__c buildPayment(
        DonationRequest request,
        Id opportunityId
    ) {
        npe01__OppPayment__c payment =
            new npe01__OppPayment__c();

        payment.npe01__Opportunity__c = opportunityId;
        payment.npe01__Payment_Amount__c = request.donationAmount;
        payment.npe01__Scheduled_Date__c = Date.today();
        return payment;
    }
    
    public void checkPaymentsWithRDToNotify(List<npe01__OppPayment__c> newRecords, Map<Id, npe01__OppPayment__c> oldRecords) {
		Map<Id, Id> oppFirstRdIds = new Map<Id, Id>();
        Map<Id, Id> oppSecondRdIds = new Map<Id, Id>();
        Map<Id, Id> allOppRdIds = new Map<Id, Id>();
		Set<Id> oppIds = new Set<Id>();
        
        for (npe01__OppPayment__c newRecord : newRecords) {
            System.debug('checkOpportunitiesWithRDToNotify 5 new:' + newRecord.npe01__Paid__c);
            System.debug('checkOpportunitiesWithRDToNotify 5 old:' + oldRecords.get(newRecord.Id).npe01__Paid__c);
            if (newRecord.npe01__Payment_Date__c != null && newRecord.npe01__Paid__c && newRecord.npe01__Paid__c <> oldRecords.get(newRecord.Id).npe01__Paid__c) {
                oppIds.add(newRecord.npe01__Opportunity__c);
            }
        }
        
        if (oppIds.isEmpty())
            return;
        
        List<Opportunity> opps = [SELECT Id, Donation_Type__c, StageName, npe03__Recurring_Donation__c, npsp__Recurring_Donation_Installment_Number__c FROM Opportunity
                                  WHERE Id IN : oppIds AND Donor_Type__c = 'Individual' AND
                                  (Donation_Type__c = 'Recurring Donation' OR Donation_Type__c = 'Sponsorship') AND 
                                  (npsp__Recurring_Donation_Installment_Number__c = 1 OR npsp__Recurring_Donation_Installment_Number__c = 2)];
        
        System.debug('checkOpportunitiesWithRDToNotify 5:' + newRecords);
		for (Opportunity opp : opps) {
            System.debug('checkOpportunitiesWithRDToNotify 5aa:' + opp.Donation_Type__c);
            System.debug('checkOpportunitiesWithRDToNotify 5ab:' + opp.StageName);
            System.debug('checkOpportunitiesWithRDToNotify 5ac:' + opp.npe03__Recurring_Donation__c);
            System.debug('checkOpportunitiesWithRDToNotify 5aD:' + opp.npsp__Recurring_Donation_Installment_Number__c);
            			
            if (opp.npsp__Recurring_Donation_Installment_Number__c == 1) {
                oppFirstRdIds.put(opp.npe03__Recurring_Donation__c, opp.Id);
            } else if (opp.npsp__Recurring_Donation_Installment_Number__c == 2) {
                oppSecondRdIds.put(opp.npe03__Recurring_Donation__c, opp.Id);   
            }
		}
        
        allOppRdIds.putAll(oppFirstRdIds);
        allOppRdIds.putAll(oppSecondRdIds);
        System.debug('checkOpportunitiesWithRDToNotify 5ba:' + oppFirstRdIds);
        System.debug('checkOpportunitiesWithRDToNotify 5bb:' + oppSecondRdIds);
        System.debug('checkOpportunitiesWithRDToNotify 5bc:' + allOppRdIds);
        if (!allOppRdIds.isEmpty()) {
            List<npe03__Recurring_Donation__c> rds = [SELECT Id, npe03__Contact__c, npe03__Contact__r.Account.Phone, npe03__Contact__r.Name, npe03__Contact__r.npe01__Preferred_Email__c, npe03__Contact__r.npe01__HomeEmail__c, npe03__Contact__r.npe01__WorkEmail__c, npe03__Contact__r.npe01__AlternateEmail__c FROM npe03__Recurring_Donation__c WHERE Id IN :allOppRdIds.keySet()]; 
            System.debug('checkOpportunitiesWithRDToNotify 6:' + rds);
        	
            for (Id allOppRdId : allOppRdIds.keySet()) {
                for (npe03__Recurring_Donation__c rd : rds) {
                    if (rd.Id == allOppRdId) {
                        Boolean isWelcomeEmail = oppSecondRdIds.containsKey(rd.Id);
                        String emailToSend = rd.npe03__Contact__r.npe01__Preferred_Email__c == 'Personal' ? rd.npe03__Contact__r.npe01__HomeEmail__c : rd.npe03__Contact__r.npe01__Preferred_Email__c == 'Work' ? rd.npe03__Contact__r.npe01__WorkEmail__c : rd.npe03__Contact__r.npe01__Preferred_Email__c == 'Alternate' ?  rd.npe03__Contact__r.npe01__AlternateEmail__c : '';
                        System.debug('checkOpportunitiesWithRDToNotify 7_:' + emailToSend);
                        if (String.isBlank(emailToSend)) 
                            continue;
                        
                        Map<String, String> params = Utils.replaceEmailTemplateParams(rd.npe03__Contact__r.Account.Phone, rd.npe03__Contact__r.Name);
                        System.debug('checkOpportunitiesWithRDToNotify 7a:' + params);
                        Id opportunityId = allOppRdIds.get(rd.Id);
                        System.debug('checkOpportunitiesWithRDToNotify 8a:' + opportunityId);
                        Utils.sendEmailByTemplate(isWelcomeEmail ? Utils.emailTemplateWelcomeEmail : Utils.emailTemplateThankYouEmail, params, opportunityId, rd.npe03__Contact__c, new List<String>{emailToSend});
                    }
                }
            }
        }
    }    
    
    //2. Change the logic behind Status field on Payment Record. If Status = Failed, Opportunity Stage = Declined.
	public void setPaymentMethodFromRD(List<npe01__OppPayment__c> newRecords) {
        Set<Id> oppIds = new Set<Id>();
        
        for (npe01__OppPayment__c newRecord : newRecords) {
            if (!oppIds.contains(newRecord.npe01__Opportunity__c)) {
                oppIds.add(newRecord.npe01__Opportunity__c);
            } 
        }
        List<Opportunity> opps = [SELECT Id, npe03__Recurring_Donation__r.npsp__PaymentMethod__c FROM Opportunity WHERE Id IN : oppIds AND npe03__Recurring_Donation__r.npsp__PaymentMethod__c <> NULL];

        for (npe01__OppPayment__c newRecord : newRecords) {
            for (Opportunity opp : opps) {
                if (newRecord.npe01__Opportunity__c == opp.Id) {
                    newRecord.npe01__Payment_Method__c = opp.npe03__Recurring_Donation__r.npsp__PaymentMethod__c;
                }
            }
        }   
    }

    public void checkPaidOption(List<npe01__OppPayment__c> newRecords, Map<Id, npe01__OppPayment__c> oldRecords) {
        Set<Id> oppIds = new Set<Id>();
        Set<Id> oppFailedIds = new Set<Id>();
        Set<Id> oppClosedLostIds = new Set<Id>();
        
        for (npe01__OppPayment__c newRecord : newRecords) {
            if (newRecord.npe01__Payment_Date__c != null && newRecord.npe01__Payment_Method__c != null) {
                if (oldRecords != null && oldRecords.size() > 0) {
                    if (oldRecords.get(newRecord.Id).npe01__Payment_Date__c <> newRecord.npe01__Payment_Date__c || 
                        oldRecords.get(newRecord.Id).npe01__Payment_Method__c <> newRecord.npe01__Payment_Method__c) {
                        newRecord.status__c = 'Paid'; 
                    }
                } else {
                    newRecord.status__c = 'Paid';
                }
            } else {
                //newRecord.status__c = 'Pending'; //Commented because Failed transactions are converted in this status
            }
            if (newRecord.npe01__Paid__c == true && newRecord.status__c != 'Paid') {
                newRecord.status__c = 'Paid';
            } 
            
            if (newRecord.npe01__Paid__c == false && newRecord.status__c == 'Paid') {
                newRecord.status__c = 'Pending';
            }

            
            System.debug('checkPaidOption newRecord.status__c: ' + newRecord.status__c);
            if (newRecord.status__c == 'Paid') {
                if (oldRecords == null || newRecord.status__c <> oldRecords.get(newRecord.Id).status__c) {
                	newRecord.npe01__Paid__c = true;
                    if (newRecord.npe01__Payment_Date__c == null) 
                        newRecord.npe01__Payment_Date__c = Date.today();
                    newRecord.npe01__Written_Off__c = false;
					oppIds.add(newRecord.npe01__Opportunity__c);
                }                
            } else if (newRecord.status__c == 'Failed') {
                System.debug('checkPaidOption newRecord.status__c: enter failed');
                if (oldRecords == null || newRecord.status__c <> oldRecords.get(newRecord.Id).status__c) {
                    System.debug('checkPaidOption newRecord.status__c: enter condition');
                	newRecord.npe01__Paid__c = false;
                    newRecord.npe01__Payment_Date__c = null;
                    newRecord.npe01__Written_Off__c = true;
                    
                    System.debug('checkPaidOption newRecord.is_OneOff_Donation__c: ' + newRecord.is_OneOff_Donation__c);
                    if (newRecord.is_OneOff_Donation__c)
                    	oppClosedLostIds.add(newRecord.npe01__Opportunity__c);
                    else
                        oppFailedIds.add(newRecord.npe01__Opportunity__c);                        
                }  
            }  
            System.debug('checkPaidOption oppFailedIds: ' + oppFailedIds);
        }        

        if (oppIds.size() > 0) {
            Database.executeBatch(new UpdateOpportunityStatusesBatch(oppIds, 'Closed Won'));
            //updateOpportunityStatus(oppIds, 'Closed Won');
        }
        if (oppFailedIds.size() > 0) {
            Database.executeBatch(new UpdateOpportunityStatusesBatch(oppFailedIds, 'Declined'));
            //updateOpportunityStatus(oppFailedIds, 'Missed');
        }
        if (oppClosedLostIds.size() > 0) {
            Database.executeBatch(new UpdateOpportunityStatusesBatch(oppClosedLostIds, 'Closed Lost'));
            //updateOpportunityStatus(oppFailedIds, 'Missed');
        }
    }

    /*@future*/
    private static void updateOpportunityStatus(Set<Id> oppIds, String newStatus) {
        List<Opportunity> opps = [SELECT Id, StageName FROM Opportunity WHERE Id IN : oppIds];

        for (Opportunity opp : opps) {
            opp.StageName = newStatus;
        }

        UPDATE opps;
    }
}