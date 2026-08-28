/**
 * Service responsible for processing ArifPay callbacks.
 */
public inherited sharing class CallbackService {
    /**
     * Processes a payment callback.
     */
    //SFESWCSD-92
    public static ArifPayCallbackResponse process(
        ArifPayCallbackRequest request
    ) {

        List<npe03__Recurring_Donation__c> recurringDonations = [
            SELECT Id
            FROM npe03__Recurring_Donation__c
            WHERE Donation_ID__c = :request.recurringUUID
        ];

        if (recurringDonations.isEmpty()) {
            throw new DonationException(
                'Recurring Donation not found.'
            );
        }
        Date todayDate = Date.today();
        Date transactionDate = request.transactionDate != NULL ? request.transactionDate : Date.today();
        Integer month = transactionDate.month(); //Integer.valueOf(request.month);
        
        List<npe01__OppPayment__c> payments = [SELECT Id, npe01__Opportunity__c, npe01__Opportunity__r.npsp__Recurring_Donation_Installment_Number__c, npe01__Opportunity__r.npe03__Recurring_Donation__c, npe01__Scheduled_Date__c, Scheduled_Date_2nd_Attempt__c, Scheduled_Date_3rd_Attempt__c, Failed_Payment_Attempts__c, npe01__Paid__c, npe01__Written_Off__c, npe01__Payment_Amount__c, npe01__Payment_Date__c, npe01__Check_Reference_Number__c, Status__c
            FROM npe01__OppPayment__c
            WHERE npe01__Opportunity__r.npe03__Recurring_Donation__c = :recurringDonations[0].Id AND
                  ((CALENDAR_MONTH(npe01__Scheduled_Date__c) =: month AND CALENDAR_YEAR(npe01__Scheduled_Date__c) =: transactionDate.year() AND (Failed_Payment_Attempts__c = 0 OR Failed_Payment_Attempts__c = NULL)) OR
                   (CALENDAR_MONTH(Scheduled_Date_2nd_Attempt__c) =: month AND CALENDAR_YEAR(Scheduled_Date_2nd_Attempt__c) =: transactionDate.year() AND Failed_Payment_Attempts__c = 1) OR //SFEUCMSD-2197
                   (CALENDAR_MONTH(Scheduled_Date_3rd_Attempt__c) =: month AND CALENDAR_YEAR(Scheduled_Date_3rd_Attempt__c) =: transactionDate.year() AND Failed_Payment_Attempts__c = 2)) AND //SFEUCMSD-2197
                   npe01__Written_Off__c = false AND npe01__Paid__c = false
            ORDER BY npe01__Scheduled_Date__c];

        if (!payments.isEmpty()) {
            npe01__OppPayment__c currentPayment = payments[0];

            boolean isPaid = String.isNotBlank(request.paymentStatus)
                ? request.paymentStatus.equalsIgnoreCase('success')
                : false;
            boolean isFailure = String.isNotBlank(request.paymentStatus)
                ? request.paymentStatus.equalsIgnoreCase('failure')
                : false;
            boolean isPending = String.isNotBlank(request.paymentStatus)
                ? request.paymentStatus.equalsIgnoreCase('pending')
                : false;

            Boolean paid1stAttempt = isPaid && currentPayment.Failed_Payment_Attempts__c == 1 && currentPayment.npe01__Scheduled_Date__c.Month() != currentPayment.Scheduled_Date_2nd_Attempt__c.Month();
            Boolean paid2ndAttempt = isPaid && currentPayment.Failed_Payment_Attempts__c == 2 && currentPayment.npe01__Scheduled_Date__c.Month() != currentPayment.Scheduled_Date_3rd_Attempt__c.Month();
            Decimal currentInstallment = currentPayment.npe01__Opportunity__r.npsp__Recurring_Donation_Installment_Number__c;
            Id rdId = currentPayment.npe01__Opportunity__r.npe03__Recurring_Donation__c;
                            
            Opportunity currentOpp = new Opportunity(Id = currentPayment.npe01__Opportunity__c);
            boolean shouldUpdatePassOpps = false;

            if (paid1stAttempt || paid2ndAttempt) {
                System.debug('enter');
                currentOpp.closeDate = Date.today(); //First step
                currentOpp.StageName = 'Missed'; //First step                   
                currentPayment.npe01__Written_Off__c = true; //First step
                updateNextPaymentToPaidByRD(currentPayment.npe01__Opportunity__r.npe03__Recurring_Donation__c, currentPayment.npe01__Opportunity__r.npsp__Recurring_Donation_Installment_Number__c + 1, todayDate); //Second step
                updateNextPaymentOnRD(currentPayment.npe01__Opportunity__r.npe03__Recurring_Donation__c, currentPayment.npe01__Opportunity__r.npsp__Recurring_Donation_Installment_Number__c); //Fourth step
                shouldUpdatePassOpps = true;
            } 
            
            if (!paid1stAttempt && !paid2ndAttempt) {
                if (isPaid) { 
                    currentOpp.CloseDate = Date.today();
                    currentOpp.StageName = 'Closed Won';
                    currentPayment.npe01__Paid__c = true;
                    shouldUpdatePassOpps = true;
                } else { 
                    Decimal nextNumber = ((currentPayment.Failed_Payment_Attempts__c != NULL) ? currentPayment.Failed_Payment_Attempts__c : 0) + 1;
                    currentPayment.Failed_Payment_Attempts__c = nextNumber;   
                    currentPayment.Failed_attempt_date__c = todayDate; 
                    if (currentPayment.Failed_Payment_Attempts__c >= 3) { //SFEUCMSD-1767
                        currentOpp.closeDate = todayDate;
                        currentOpp.StageName = 'Missed';                                
                        currentPayment.npe01__Written_Off__c = true;
                        shouldUpdatePassOpps = true;
                    }                                
                }
            }

            if (shouldUpdatePassOpps) { 
                updatePastOpportunitiesByRDAndInstallment(rdId, currentInstallment); 
            }

            currentPayment.Status__c = isPaid ? 'Paid' : isFailure ? 'Failed' : 'Pending';

            currentPayment.npe01__Paid__c = false;
            currentPayment.npe01__Written_Off__c = false;

            if (isPaid) {
                currentPayment.npe01__Paid__c = true;
            }
            if (isFailure) {
                currentPayment.npe01__Written_Off__c = true;
            }

            currentPayment.npe01__Payment_Date__c = request.transactionDate;
            currentPayment.npe01__Check_Reference_Number__c = request.referenceId;
            UPDATE currentPayment;
        }

        ArifPayCallbackResponse response =
            new ArifPayCallbackResponse();

        response.success = true;
        response.message = ApiConstants.MSG_PAYMENT_RECEIVED;

        return response;

    }

    public static void updatePastOpportunitiesByRDAndInstallment(Id rdId, Decimal currentInstallment) {
        List<Opportunity> oppsToUpdate = [SELECT Id, Stagename FROM Opportunity WHERE npe03__Recurring_Donation__c =: rdId AND npsp__Recurring_Donation_Installment_Number__c <: currentInstallment AND Stagename = 'Pledged'];
        if (oppsToUpdate.isEmpty())
            return;
	
        Set<Id> oppIds = (new Map<Id, Opportunity>(oppsToUpdate)).keySet();
        List<npe01__OppPayment__c> paysToUpdate = [SELECT Id, npe01__Paid__c, npe01__Written_Off__c FROM npe01__OppPayment__c WHERE npe01__Opportunity__c IN : oppIds];
            
		System.debug('###updatePastOpportunitiesByRDAndInstallment currentInstallment:' + currentInstallment);        
        for (Opportunity oppToUpdate : oppsToUpdate) {
            oppToUpdate.Stagename = 'Missed';
            System.debug('###updatePastOpportunitiesByRDAndInstallment oppToUpdate.Id:' + oppToUpdate.Id);        
        }
        
        Database.SaveResult[] sr = Database.update(oppsToUpdate, false);
        System.debug('###updatePastOpportunitiesByRD opps sr:' + sr);
        
        for (npe01__OppPayment__c pay : paysToUpdate) {
            pay.npe01__Paid__c = false;
            pay.npe01__Written_Off__c = true;
        } 
        
        sr = Database.update(paysToUpdate, false);
        System.debug('###updatePastOpportunitiesByRD pays sr:' + sr);
    }   

    public static void updateNextPaymentOnRD(Id rdId, Decimal currentInstallment) {
        Decimal nextInstallment = currentInstallment + 2;
        System.debug('###InsertPaymentData UPD 2 updateNextPaymentOnRD nextInstallment:' + nextInstallment);
        List<npe01__OppPayment__c> paysToUpdate = [SELECT Id, Name, npe01__Opportunity__r.Name, npe01__Scheduled_Date__c FROM npe01__OppPayment__c WHERE npe01__Opportunity__r.npe03__Recurring_Donation__c =: rdId AND npe01__Opportunity__r.npsp__Recurring_Donation_Installment_Number__c =: nextInstallment];
        System.debug('###InsertPaymentData UPD 2 updateNextPaymentOnRD paysToUpdate:' + paysToUpdate);
        
        if (paysToUpdate.isEmpty())
            return;
        
        Date nextPaymentDate = NULL;
        for (npe01__OppPayment__c payToUpdate : paysToUpdate) {
            nextPaymentDate = payToUpdate.npe01__Scheduled_Date__c;
        }
        
        System.debug('###InsertPaymentData UPD 2 updateNextPaymentOnRD nextPaymentDate:' + nextPaymentDate);
            
        if (nextPaymentDate != NULL) {
            List<npe03__Recurring_Donation__c> rdsToUpdate = [SELECT Id, Name, npe03__Next_Payment_Date__c FROM npe03__Recurring_Donation__c WHERE Id =: rdId];
            System.debug('###InsertPaymentData UPD 2 updateNextPaymentOnRD rdsToUpdate:' + rdsToUpdate);
            
            if (rdsToUpdate.isEmpty())
                return;
            
            for (npe03__Recurring_Donation__c rdToUpdate : rdsToUpdate) {
                rdToUpdate.npe03__Next_Payment_Date__c = nextPaymentDate;
            }
            
            Database.SaveResult[] sr = Database.update(rdsToUpdate, false);
            System.debug('###InsertPaymentData UPD 2 updateNextPaymentOnRD rds sr:' + sr);        
        }
    }  
    
    public static void updateNextPaymentToPaidByRD(Id rdId, Decimal currentInstallment, Date nextDate) {
        System.debug('###InsertPaymentData UPD 1 updateNextPaymentToPaidByRD currentInstallment:' + currentInstallment);
        List<npe01__OppPayment__c> paysToUpdate = [SELECT Id, Name, npe01__Opportunity__c, npe01__Opportunity__r.Name,  npe01__Payment_Date__c, npe01__Paid__c FROM npe01__OppPayment__c WHERE npe01__Opportunity__r.npe03__Recurring_Donation__c =: rdId AND npe01__Opportunity__r.npsp__Recurring_Donation_Installment_Number__c =: currentInstallment];
        System.debug('###InsertPaymentData UPD 1 updateNextPaymentToPaidByRD paysToUpdate:' + paysToUpdate);
        
        if (paysToUpdate.isEmpty())
            return;
        
        for (npe01__OppPayment__c payToUpdate : paysToUpdate) {
            payToUpdate.npe01__Payment_Date__c = nextDate;
            payToUpdate.npe01__Paid__c = true;
        }
        
        Database.SaveResult[] sr = Database.update(paysToUpdate, false);
        System.debug('###InsertPaymentData UPD 1 updatePastOpportunitiesByRD pays sr:' + sr);
        
        if (!paysToUpdate.isEmpty()) {
            Opportunity oppToUpdate = new Opportunity(Id = paysToUpdate[0].npe01__Opportunity__c, CloseDate = nextDate, StageName = 'Closed Won');
            sr = Database.update(new List<Opportunity>{oppToUpdate}, false);
            System.debug('###InsertPaymentData UPD 1 updatePastOpportunitiesByRD opps sr:' + sr);
        }
    }  
}
