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
        payment.npe01__Payment_Amount__c = request.amount;
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
            //SFEUCMSD-134 Paid set to true closes the opportunity as Closed Won even when the status already was Paid
            boolean isPaidChangedToTrue = newRecord.npe01__Paid__c && (oldRecords == null || !oldRecords.get(newRecord.Id).npe01__Paid__c);
            if (newRecord.npe01__Paid__c == true && newRecord.status__c != 'Paid') {
                newRecord.status__c = 'Paid';
            } 
            
            if (newRecord.npe01__Paid__c == false && newRecord.status__c == 'Paid') {
                newRecord.status__c = 'Pending';
            }

            
            System.debug('checkPaidOption newRecord.status__c: ' + newRecord.status__c);
            if (newRecord.status__c == 'Paid') {
                if (oldRecords == null || newRecord.status__c <> oldRecords.get(newRecord.Id).status__c || isPaidChangedToTrue) { //SFEUCMSD-134
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
                    //SFESWCSD-92: retries 1 and 2 stay open; no attempt count (legacy) or the 3rd failure writes off
                    newRecord.npe01__Written_Off__c = newRecord.Failed_Payment_Attempts__c == null || newRecord.Failed_Payment_Attempts__c >= 3;
                    
                    System.debug('checkPaidOption newRecord.is_OneOff_Donation__c: ' + newRecord.is_OneOff_Donation__c);
                    if (newRecord.is_OneOff_Donation__c)
                    	oppClosedLostIds.add(newRecord.npe01__Opportunity__c);
                    else
                        oppFailedIds.add(newRecord.npe01__Opportunity__c);                        
                }  
            }  
            System.debug('checkPaidOption oppFailedIds: ' + oppFailedIds);
        }        

        //SFESWCSD-113
        Map<String, Set<Id>> opportunityIdsByStatus = new Map<String, Set<Id>>();
        if (oppIds.size() > 0) {
            //Database.executeBatch(new UpdateOpportunityStatusesBatch(oppIds, 'Closed Won'));
            //updateOpportunityStatus(oppIds, 'Closed Won');
            opportunityIdsByStatus.put('Closed Won', oppIds);
        }
        if (oppFailedIds.size() > 0) {
            //Database.executeBatch(new UpdateOpportunityStatusesBatch(oppFailedIds, 'Declined'));
            //updateOpportunityStatus(oppFailedIds, 'Missed');
            opportunityIdsByStatus.put('Declined', oppFailedIds);
        }
        if (oppClosedLostIds.size() > 0) {
            //Database.executeBatch(new UpdateOpportunityStatusesBatch(oppClosedLostIds, 'Closed Lost'));
            //updateOpportunityStatus(oppClosedLostIds, 'Closed Lost');
            opportunityIdsByStatus.put('Closed Lost', oppClosedLostIds);
        }
        scheduleOpportunityStatusUpdates(opportunityIdsByStatus, System.isBatch() || System.isFuture());
    }

    //SFESWCSD-113 Database.executeBatch cannot be called from a batch or future method, so a queueable job (or a direct update when no job can be queued) is used there
    @TestVisible
    private static void scheduleOpportunityStatusUpdates(Map<String, Set<Id>> opportunityIdsByStatus, Boolean isBatchOrFutureContext) {
        if (opportunityIdsByStatus == null || opportunityIdsByStatus.isEmpty()) {
            return;
        }

        if (!isBatchOrFutureContext) {
            for (String status : opportunityIdsByStatus.keySet()) {
                Database.executeBatch(new UpdateOpportunityStatusesBatch(opportunityIdsByStatus.get(status), status));
            }
            return;
        }

        if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(new UpdateOpportunityStatusesQueueable(opportunityIdsByStatus));
            return;
        }

        for (String status : opportunityIdsByStatus.keySet()) {
            updateOpportunityStatus(opportunityIdsByStatus.get(status), status);
        }
    }

    /*@future*/
    private static void updateOpportunityStatus(Set<Id> oppIds, String newStatus) {
        List<Opportunity> opps = [SELECT Id, StageName, Name, CloseDate FROM Opportunity WHERE Id IN : oppIds]; //SFEUCMSD-134 Name and CloseDate are needed for the Payment Date

        for (Opportunity opp : opps) {
            opp.StageName = newStatus;
        }
        if (newStatus == 'Closed Won') {
            applyLatestPaymentDate(opps); //SFEUCMSD-134
        }

        UPDATE opps;
    }

    //SFEUCMSD-134 The Opportunity Close Date follows the Payment Date once it is populated or changed on a payment that is already paid, the latest date wins when several payments of one opportunity change together
    public void updateOpportunityCloseDate(List<npe01__OppPayment__c> newRecords, Map<Id, npe01__OppPayment__c> oldRecords) {
        if (newRecords == null || oldRecords == null) {
            return;
        }

        Map<Id, Date> paymentDateByOpportunityId = new Map<Id, Date>();
        for (npe01__OppPayment__c newRecord : newRecords) {
            npe01__OppPayment__c oldRecord = oldRecords.get(newRecord.Id);
            if (oldRecord == null || newRecord.npe01__Opportunity__c == null || newRecord.npe01__Payment_Date__c == null || newRecord.npe01__Payment_Date__c == oldRecord.npe01__Payment_Date__c) {
                continue;
            }
            //SFEUCMSD-134 A payment being marked as Paid moves the opportunity to Closed Won, that update carries the Close Date because NPSP resets it when it is not changed in the same update
            if (newRecord.npe01__Paid__c && (!oldRecord.npe01__Paid__c || oldRecord.status__c != 'Paid')) {
                continue;
            }
            Date currentDate = paymentDateByOpportunityId.get(newRecord.npe01__Opportunity__c);
            if (currentDate == null || newRecord.npe01__Payment_Date__c > currentDate) {
                paymentDateByOpportunityId.put(newRecord.npe01__Opportunity__c, newRecord.npe01__Payment_Date__c);
            }
        }
        if (paymentDateByOpportunityId.isEmpty()) {
            return;
        }

        applyPaymentDates(paymentDateByOpportunityId);
    }

    //SFEUCMSD-134 Sets the Close Date and the trailing name date of each opportunity, the update is skipped when nothing changes
    private static void applyPaymentDates(Map<Id, Date> paymentDateByOpportunityId) {
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        for (Opportunity opp : [SELECT Id, Name, CloseDate FROM Opportunity WHERE Id IN :paymentDateByOpportunityId.keySet()]) {
            Date paymentDate = paymentDateByOpportunityId.get(opp.Id);
            //SFEUCMSD-134 Opportunity name override disabled, only the Close Date follows the Payment Date
            //String newName = replaceTrailingNameDate(opp.Name, paymentDate);
            if (opp.CloseDate != paymentDate) {
                Opportunity opportunityToUpdate = new Opportunity(Id = opp.Id, CloseDate = paymentDate);
                //if (opp.Name != newName) {
                //    opportunityToUpdate.Name = newName;
                //}
                opportunitiesToUpdate.add(opportunityToUpdate);
            }
        }
        if (!opportunitiesToUpdate.isEmpty()) {
            UPDATE opportunitiesToUpdate;
        }
    }

    //SFEUCMSD-134 Sets the latest paid Payment Date and its name date in memory, so the stage update to Closed Won carries them in the same DML and NPSP cannot reset the Close Date between two updates
    public static void applyLatestPaymentDate(List<Opportunity> opportunities) {
        if (opportunities == null || opportunities.isEmpty()) {
            return;
        }
        Map<Id, Date> paymentDateByOpportunityId = new Map<Id, Date>();
        for (AggregateResult result : [SELECT npe01__Opportunity__c oppId, MAX(npe01__Payment_Date__c) paymentDate FROM npe01__OppPayment__c
                                       WHERE npe01__Opportunity__c IN :new Map<Id, Opportunity>(opportunities).keySet() AND npe01__Paid__c = true AND npe01__Payment_Date__c != null
                                       GROUP BY npe01__Opportunity__c]) {
            paymentDateByOpportunityId.put((Id) result.get('oppId'), (Date) result.get('paymentDate'));
        }
        for (Opportunity opportunity : opportunities) {
            Date paymentDate = paymentDateByOpportunityId.get(opportunity.Id);
            if (paymentDate != null) {
                opportunity.CloseDate = paymentDate;
                //SFEUCMSD-134 Opportunity name override disabled
                //opportunity.Name = replaceTrailingNameDate(opportunity.Name, paymentDate);
            }
        }
    }

    //SFEUCMSD-134 A name ending with a dd/MM/yyyy or yyyy-MM-dd date gets the new date in the same format, any other name is returned as it is
    @TestVisible
    private static String replaceTrailingNameDate(String name, Date newDate) {
        if (String.isBlank(name) || newDate == null) {
            return name;
        }
        Integer index = name.lastIndexOf(' ');
        if (index < 0) {
            return name;
        }
        String lastToken = name.substring(index + 1);
        Datetime newDatetime = Datetime.newInstance(newDate.year(), newDate.month(), newDate.day());
        if (Pattern.matches('\\d{2}/\\d{2}/\\d{4}', lastToken)) {
            return name.substring(0, index + 1) + newDatetime.format('dd/MM/yyyy');
        }
        if (Pattern.matches('\\d{4}-\\d{2}-\\d{2}', lastToken)) {
            return name.substring(0, index + 1) + newDatetime.format('yyyy-MM-dd');
        }
        return name;
    }

}