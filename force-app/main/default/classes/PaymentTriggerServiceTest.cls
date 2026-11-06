@isTest
private class PaymentTriggerServiceTest {
	private static Account acc;
    private static Contact con;
    private static npe03__Recurring_Donation__c donation1;
    private static Id recordTypeOppId;
    private static Id recordTypeAccId;
        
    @TestSetup
    public static void setup() {
    	recordTypeAccId = [SELECT Id FROM RecordType WHERE Name='Household Account' AND SObjectType='Account' LIMIT 1].Id;
        acc = new Account(name = 'test', RecordTypeId = recordTypeAccId);
        INSERT acc;
        
        con = new Contact(LastName='Peréz', FirstName='Juan', email='test@gmail.com', npe01__PreferredPhone__c = 'Home', npe01__Preferred_Email__c = 'Personal');
        con.AccountId = acc.Id;         
        INSERT con;
        
        Date lastPaymentDate = Date.today().addDays(-1);
		
        donation1 = new npe03__Recurring_Donation__c();
        donation1.Name = 'CCD TEST 1';
        donation1.npe03__Open_Ended_Status__c = 'Open';
        donation1.npe03__Schedule_Type__c = 'Monthly';
        donation1.npe03__Contact__c = con.Id;
        donation1.npe03__Last_Payment_Date__c = lastPaymentDate;
        donation1.npe03__Next_Payment_Date__c = Date.today();
        donation1.npe03__Amount__c=1000;
        donation1.npsp__PaymentMethod__c = 'Check';
        donation1.Donor_Type__c = 'Individual';
        donation1.Donation_Type__c = 'Recurring Donation';
        INSERT donation1;
        
        //Id, FROM Opportunity WHERE npe03__Recurring_Donation__c IN : rdIds AND ((CALENDAR_YEAR(CloseDate) =: currentMonth.Year() AND CALENDAR_MONTH(CloseDate) =: currentMonth.Month()) OR (CALENDAR_YEAR(CloseDate) =: nextMonth.Year() AND CALENDAR_MONTH(CloseDate) =: nextMonth.Month()))
            
            
        
        List<Opportunity> opps = [SELECT Id FROM Opportunity];
        System.debug('opps:' + opps);
    }
    
    @isTest 
    public static void CheckPaymentCreation(){
     	con = [SELECT Id, AccountId, LastName, FirstName, email, npe01__PreferredPhone__c, npe01__Preferred_Email__c FROM Contact LIMIT 1];
        acc = [SELECT Id, name, RecordTypeId FROM Account LIMIT 1];
        donation1 = [SELECT Id, Name, npe03__Open_Ended_Status__c, npe03__Schedule_Type__c, npe03__Contact__c, npe03__Last_Payment_Date__c, npe03__Next_Payment_Date__c, npe03__Amount__c FROM npe03__Recurring_Donation__c LIMIT 1];
        recordTypeOppId = [SELECT Id FROM RecordType WHERE Name='Donation' AND SObjectType='Opportunity' LIMIT 1].Id;
        
        Opportunity opp1 = new Opportunity();
        opp1.npe03__Recurring_Donation__c = donation1.Id;
        //opp1.StageName = 'Closed Won';
        opp1.StageName = 'Pledged';
        opp1.AccountId = acc.Id;
        opp1.RecordTypeId = recordTypeOppId;
        opp1.Name = 'opp1';
        opp1.Amount = 1000;
        opp1.CloseDate = Date.today().addMonths(1);
        opp1.npsp__Recurring_Donation_Installment_Number__c = 1;
        opp1.ContactId = con.Id;
        INSERT opp1;
        
        List<npe01__OppPayment__c> oppPays = [SELECT Id FROM npe01__OppPayment__c WHERE npe01__Opportunity__c =: opp1.Id AND status__c <> 'Paid' AND npe01__Payment_Date__c = NULL];
        System.assert(oppPays.size() > 0);
        
        for (npe01__OppPayment__c oppPay : oppPays) {
            oppPay.npe01__Payment_Method__c = 'Cash';
            oppPay.status__c = 'Paid';
        }
        
        UPDATE oppPays; 
        
        opp1.StageName = 'Closed Won';
        UPDATE opp1; 
        
        oppPays = [SELECT Id FROM npe01__OppPayment__c WHERE npe01__Opportunity__c =: opp1.Id AND npe01__Paid__c = true AND npe01__Payment_Date__c <> NULL];
        System.assert(oppPays.size() > 0);
    }
    
    @isTest 
    public static void CheckPaymentCreationFailed(){
     	con = [SELECT Id, AccountId, LastName, FirstName, email, npe01__PreferredPhone__c, npe01__Preferred_Email__c FROM Contact LIMIT 1];
        acc = [SELECT Id, name, RecordTypeId FROM Account LIMIT 1];
        donation1 = [SELECT Id, Name, npe03__Open_Ended_Status__c, npe03__Schedule_Type__c, npe03__Contact__c, npe03__Last_Payment_Date__c, npe03__Next_Payment_Date__c, npe03__Amount__c FROM npe03__Recurring_Donation__c LIMIT 1];
        recordTypeOppId = [SELECT Id FROM RecordType WHERE Name='Donation' AND SObjectType='Opportunity' LIMIT 1].Id;
        
        Opportunity opp1 = new Opportunity();
        opp1.npe03__Recurring_Donation__c = donation1.Id;
        //opp1.StageName = 'Closed Won';
        opp1.StageName = 'Pledged';
        opp1.AccountId = acc.Id;
        opp1.RecordTypeId = recordTypeOppId;
        opp1.Name = 'opp1';
        opp1.Amount = 1000;
        opp1.CloseDate = Date.today().addMonths(1);
        opp1.npsp__Recurring_Donation_Installment_Number__c = 2;
        opp1.ContactId = con.Id;
        INSERT opp1;
        
        List<npe01__OppPayment__c> oppPays = [SELECT Id FROM npe01__OppPayment__c WHERE npe01__Opportunity__c =: opp1.Id AND status__c <> 'Paid' AND npe01__Payment_Date__c = NULL];
        System.assert(oppPays.size() > 0);
        
        for (npe01__OppPayment__c oppPay : oppPays) {
            oppPay.npe01__Payment_Method__c = 'Cash';
            oppPay.status__c = 'Failed';
            oppPay.npe01__Payment_Date__c = null;
            oppPay.npe01__Paid__c = false; 
        }
        
        UPDATE oppPays; 
    }

    //SFEUCMSD-134
    private static Opportunity createDonationOpp(String oppName) {
        Contact c = [SELECT Id, AccountId FROM Contact LIMIT 1];
        npe03__Recurring_Donation__c rd = [SELECT Id FROM npe03__Recurring_Donation__c LIMIT 1];
        Opportunity opp = new Opportunity(
            npe03__Recurring_Donation__c = rd.Id,
            StageName = 'Pledged',
            AccountId = c.AccountId,
            ContactId = c.Id,
            RecordTypeId = [SELECT Id FROM RecordType WHERE Name = 'Donation' AND SObjectType = 'Opportunity' LIMIT 1].Id,
            Name = oppName,
            Donor_Type__c = 'Individual',
            Donation_Type__c = 'Recurring Donation',
            Amount = 1000,
            CloseDate = Date.today().addMonths(1),
            npsp__Recurring_Donation_Installment_Number__c = 1
        );
        INSERT opp;
        return opp;
    }

    //SFEUCMSD-134
    private static npe01__OppPayment__c getFirstPayment(Id oppId) {
        return [SELECT Id, npe01__Opportunity__c, npe01__Paid__c, npe01__Payment_Date__c, npe01__Payment_Method__c, npe01__Scheduled_Date__c, npe01__Written_Off__c, status__c, is_OneOff_Donation__c, Failed_Payment_Attempts__c
                FROM npe01__OppPayment__c WHERE npe01__Opportunity__c = :oppId ORDER BY CreatedDate LIMIT 1];
    }

    //SFEUCMSD-134 The TDTM handler does not run in test context, so the handler is called directly with the old and new versions of the payment
    private static npe01__OppPayment__c runHandler(npsp.TDTM_Runnable.Action action, npe01__OppPayment__c oldPayment, npe01__OppPayment__c newPayment) {
        new PaymentTriggerHandler_TDTM().run(new List<npe01__OppPayment__c>{ newPayment }, new List<npe01__OppPayment__c>{ oldPayment }, action, npe01__OppPayment__c.SObjectType.getDescribe());
        return newPayment;
    }

    //SFEUCMSD-134
    private static void payFirstPayment(Id oppId, Date paymentDate) {
        npe01__OppPayment__c payment = getFirstPayment(oppId);
        payment.npe01__Payment_Method__c = 'Cash';
        payment.npe01__Paid__c = true;
        payment.npe01__Payment_Date__c = paymentDate;
        UPDATE payment;
    }

    //SFEUCMSD-134
    @isTest
    public static void paidTrue_setsPaidStatusAndClosesOpportunityWon() {
        Opportunity opp = createDonationOpp('Donor Donation 2026-11-05');
        npe01__OppPayment__c oldPayment = getFirstPayment(opp.Id);
        Assert.areNotEqual('Closed Won', [SELECT StageName FROM Opportunity WHERE Id = :opp.Id].StageName, 'Precondition: the opportunity must not be Closed Won yet.');
        npe01__OppPayment__c newPayment = oldPayment.clone(true, false, false, false);
        newPayment.npe01__Paid__c = true;

        Test.startTest();
        runHandler(npsp.TDTM_Runnable.Action.BeforeUpdate, oldPayment, newPayment);
        Test.stopTest();

        Assert.areEqual('Paid', newPayment.status__c, 'Paid must set the payment status to Paid.');
        Assert.areEqual(Date.today(), newPayment.npe01__Payment_Date__c, 'An empty Payment Date must default to today.');
        Assert.isFalse(newPayment.npe01__Written_Off__c, 'A paid payment must not be written off.');
        Assert.areEqual('Closed Won', [SELECT StageName FROM Opportunity WHERE Id = :opp.Id].StageName, 'Paid must move the opportunity to Closed Won.');
    }

    //SFEUCMSD-134
    @isTest
    public static void paymentDatePopulated_setsOpportunityCloseDateAndKeepsScheduledDate() {
        Opportunity opp = createDonationOpp('Donor Donation 2026-11-05');
        Date paymentDate = Date.today().addDays(-3);
        Assert.areNotEqual(paymentDate, [SELECT CloseDate FROM Opportunity WHERE Id = :opp.Id].CloseDate, 'Precondition: the close date must differ from the payment date.');
        npe01__OppPayment__c oldPayment = getFirstPayment(opp.Id);
        Date scheduledDateBefore = oldPayment.npe01__Scheduled_Date__c;
        payFirstPayment(opp.Id, paymentDate);
        npe01__OppPayment__c newPayment = getFirstPayment(opp.Id);
        oldPayment.npe01__Paid__c = true;
        oldPayment.status__c = 'Paid';

        Test.startTest();
        new PaymentTriggerService().updateOpportunityCloseDate(new List<npe01__OppPayment__c>{ newPayment }, new Map<Id, npe01__OppPayment__c>{ oldPayment.Id => oldPayment });
        Test.stopTest();

        Assert.areEqual(paymentDate, [SELECT CloseDate FROM Opportunity WHERE Id = :opp.Id].CloseDate, 'The Close Date must equal the Payment Date.');
        Assert.areEqual(scheduledDateBefore, getFirstPayment(opp.Id).npe01__Scheduled_Date__c, 'The Scheduled Date of the paid payment must not change.');
    }

    //SFEUCMSD-134
    @isTest
    public static void paymentDateChanged_updatesOpportunityCloseDateAgain() {
        Opportunity opp = createDonationOpp('Donor Donation 2026-11-05');
        npe01__OppPayment__c basePayment = getFirstPayment(opp.Id);
        npe01__OppPayment__c oldPayment = basePayment.clone(true, false, false, false);
        oldPayment.npe01__Payment_Date__c = Date.today().addDays(-5);
        npe01__OppPayment__c newPayment = basePayment.clone(true, false, false, false);
        newPayment.npe01__Payment_Date__c = Date.today().addDays(-2);

        Test.startTest();
        new PaymentTriggerService().updateOpportunityCloseDate(new List<npe01__OppPayment__c>{ newPayment }, new Map<Id, npe01__OppPayment__c>{ oldPayment.Id => oldPayment });
        Test.stopTest();

        Assert.areEqual(Date.today().addDays(-2), [SELECT CloseDate FROM Opportunity WHERE Id = :opp.Id].CloseDate, 'A changed Payment Date must update the Close Date again.');
    }

    //SFEUCMSD-134
    @isTest
    public static void paymentWithoutDateChange_keepsOpportunityCloseDate() {
        Opportunity opp = createDonationOpp('Donor Donation 2026-11-05');
        Date closeDateBefore = [SELECT CloseDate FROM Opportunity WHERE Id = :opp.Id].CloseDate;
        npe01__OppPayment__c oldPayment = getFirstPayment(opp.Id);
        npe01__OppPayment__c newPayment = oldPayment.clone(true, false, false, false);
        newPayment.npe01__Payment_Method__c = 'Cash';

        Test.startTest();
        new PaymentTriggerService().updateOpportunityCloseDate(new List<npe01__OppPayment__c>{ newPayment }, new Map<Id, npe01__OppPayment__c>{ oldPayment.Id => oldPayment });
        Test.stopTest();

        Assert.areEqual(closeDateBefore, [SELECT CloseDate FROM Opportunity WHERE Id = :opp.Id].CloseDate, 'Without a Payment Date change the Close Date must not change.');
    }

    //SFEUCMSD-134 Opportunity name override disabled, the name keeps its original date
    @isTest
    public static void paymentDatePopulated_keepsTrailingDateInOpportunityName() {
        Opportunity opp = createDonationOpp('Jorge Salcedo P12 Donation 2026-11-05');
        npe01__OppPayment__c oldPayment = getFirstPayment(opp.Id);
        npe01__OppPayment__c newPayment = oldPayment.clone(true, false, false, false);
        newPayment.npe01__Payment_Date__c = Date.newInstance(2026, 11, 20);

        Test.startTest();
        runHandler(npsp.TDTM_Runnable.Action.AfterUpdate, oldPayment, newPayment);
        Test.stopTest();

        opp = [SELECT Name, CloseDate FROM Opportunity WHERE Id = :opp.Id];
        //SFEUCMSD-134
        Assert.areEqual('Jorge Salcedo P12 Donation 2026-11-05', opp.Name, 'The opportunity name must not be overridden by the Payment Date.');
        Assert.areEqual(Date.newInstance(2026, 11, 20), opp.CloseDate, 'The Close Date must follow the Payment Date.');
    }

    //SFEUCMSD-134
    @isTest
    public static void paymentDatePopulated_keepsOpportunityNameWithoutTrailingDate() {
        Opportunity opp = createDonationOpp('Opportunity ABC123');
        npe01__OppPayment__c oldPayment = getFirstPayment(opp.Id);
        npe01__OppPayment__c newPayment = oldPayment.clone(true, false, false, false);
        newPayment.npe01__Payment_Date__c = Date.today().addDays(-3);

        Test.startTest();
        new PaymentTriggerService().updateOpportunityCloseDate(new List<npe01__OppPayment__c>{ newPayment }, new Map<Id, npe01__OppPayment__c>{ oldPayment.Id => oldPayment });
        Test.stopTest();

        opp = [SELECT Name, CloseDate FROM Opportunity WHERE Id = :opp.Id];
        Assert.areEqual('Opportunity ABC123', opp.Name, 'A name without a trailing date must not change.');
        Assert.areEqual(Date.today().addDays(-3), opp.CloseDate, 'The Close Date must still follow the Payment Date.');
    }

    //SFEUCMSD-134
    @isTest
    public static void replaceTrailingNameDate_handlesEdgeCases() {
        Date newDate = Date.newInstance(2026, 12, 1);

        Assert.areEqual('Donation 01/12/2026', PaymentTriggerService.replaceTrailingNameDate('Donation 15/06/2025', newDate), 'A trailing dd/MM/yyyy date must be replaced.');
        Assert.areEqual('Donation 2026-12-01', PaymentTriggerService.replaceTrailingNameDate('Donation 2025-06-15', newDate), 'A trailing yyyy-MM-dd date must be replaced keeping its format.');
        Assert.areEqual('Donation 15.06.2025', PaymentTriggerService.replaceTrailingNameDate('Donation 15.06.2025', newDate), 'Any other date format must not be replaced.');
        Assert.areEqual('NoSpaces', PaymentTriggerService.replaceTrailingNameDate('NoSpaces', newDate), 'A name without spaces must not change.');
        Assert.areEqual('Donation 15/06/2025 (2)', PaymentTriggerService.replaceTrailingNameDate('Donation 15/06/2025 (2)', newDate), 'A date that is not the last token must not be replaced.');
        Assert.isNull(PaymentTriggerService.replaceTrailingNameDate(null, newDate), 'A null name must stay null.');
        Assert.areEqual('Donation 15/06/2025', PaymentTriggerService.replaceTrailingNameDate('Donation 15/06/2025', null), 'A null date must not change the name.');
    }

    //SFEUCMSD-134
    @isTest
    public static void updateOpportunityCloseDate_withoutRecords_doesNothing() {
        PaymentTriggerService service = new PaymentTriggerService();

        Test.startTest();
        Integer dmlBefore = Limits.getDmlStatements();
        service.updateOpportunityCloseDate(null, null);
        service.updateOpportunityCloseDate(new List<npe01__OppPayment__c>(), new Map<Id, npe01__OppPayment__c>());
        Assert.areEqual(dmlBefore, Limits.getDmlStatements(), 'No DML is expected without payment changes.');
        Test.stopTest();
    }

    //SFEUCMSD-134 Closed Won resets the Close Date to today in the org, the sync applies the paid Payment Date again
    @isTest
    public static void applyLatestPaymentDate_setsCloseDateAndNameFromLatestPaidPayment() {
        Opportunity opp = createDonationOpp('Donor Donation 2026-11-05');
        Date paymentDate = Date.newInstance(2026, 11, 20);
        payFirstPayment(opp.Id, paymentDate);
        Opportunity staleOpportunity = [SELECT Id, Name, CloseDate FROM Opportunity WHERE Id = :opp.Id];
        staleOpportunity.CloseDate = Date.newInstance(2026, 11, 5);
        staleOpportunity.Name = 'Jorge Salcedo P12 Donation 2026-11-05';

        Test.startTest();
        PaymentTriggerService.applyLatestPaymentDate(new List<Opportunity>{ staleOpportunity });
        Test.stopTest();

        Assert.areEqual(paymentDate, staleOpportunity.CloseDate, 'The Close Date must be taken from the paid Payment Date.');
        //SFEUCMSD-134 Opportunity name override disabled
        Assert.areEqual('Jorge Salcedo P12 Donation 2026-11-05', staleOpportunity.Name, 'The opportunity name must not be overridden by the Payment Date.');
    }

    //SFEUCMSD-134
    @isTest
    public static void applyLatestPaymentDate_ignoresUnpaidPaymentsAndEmptyInput() {
        Opportunity opp = createDonationOpp('Donor Donation 2026-11-05');
        Opportunity unpaidOpportunity = [SELECT Id, Name, CloseDate FROM Opportunity WHERE Id = :opp.Id];
        Date closeDateBefore = unpaidOpportunity.CloseDate;
        String nameBefore = unpaidOpportunity.Name;

        Test.startTest();
        PaymentTriggerService.applyLatestPaymentDate(null);
        PaymentTriggerService.applyLatestPaymentDate(new List<Opportunity>());
        PaymentTriggerService.applyLatestPaymentDate(new List<Opportunity>{ unpaidOpportunity });
        Test.stopTest();

        Assert.areEqual(closeDateBefore, unpaidOpportunity.CloseDate, 'An opportunity without paid payments must keep its Close Date.');
        Assert.areEqual(nameBefore, unpaidOpportunity.Name, 'An opportunity without paid payments must keep its name.');
    }

    //SFEUCMSD-134
    @isTest
    public static void closedWonQueueable_appliesPaymentDateAfterStageUpdate() {
        Opportunity opp = createDonationOpp('Donor Donation 2026-11-05');
        Date paymentDate = Date.newInstance(2026, 11, 20);
        payFirstPayment(opp.Id, paymentDate);
        opp = [SELECT Id FROM Opportunity WHERE Id = :opp.Id];
        opp.CloseDate = Date.newInstance(2026, 11, 5);
        UPDATE opp;

        Test.startTest();
        System.enqueueJob(new UpdateOpportunityStatusesQueueable(new Map<String, Set<Id>>{ 'Closed Won' => new Set<Id>{ opp.Id } }));
        Test.stopTest();

        opp = [SELECT StageName, CloseDate FROM Opportunity WHERE Id = :opp.Id];
        Assert.areEqual('Closed Won', opp.StageName, 'The queueable must move the opportunity to Closed Won.');
        Assert.areEqual(paymentDate, opp.CloseDate, 'The queueable must apply the Payment Date after the stage update.');
    }

    //SFEUCMSD-134
    @isTest
    public static void closedWonBatch_appliesPaymentDateAfterStageUpdate() {
        Opportunity opp = createDonationOpp('Donor Donation 2026-11-05');
        Date paymentDate = Date.newInstance(2026, 11, 20);
        payFirstPayment(opp.Id, paymentDate);
        opp = [SELECT Id FROM Opportunity WHERE Id = :opp.Id];
        opp.CloseDate = Date.newInstance(2026, 11, 5);
        UPDATE opp;

        Test.startTest();
        Database.executeBatch(new UpdateOpportunityStatusesBatch(new Set<Id>{ opp.Id }, 'Closed Won'));
        Test.stopTest();

        opp = [SELECT StageName, CloseDate FROM Opportunity WHERE Id = :opp.Id];
        Assert.areEqual('Closed Won', opp.StageName, 'The batch must move the opportunity to Closed Won.');
        Assert.areEqual(paymentDate, opp.CloseDate, 'The batch must apply the Payment Date after the stage update.');
    }

    //SFEUCMSD-134 Covers the notification path that runs next to the Close Date sync in the after update event
    @isTest
    public static void afterUpdateHandler_runsNotificationsAndLeavesCloseDateToTheStageUpdate() {
        Opportunity opp = createDonationOpp('Donor Donation 2026-11-05');
        npe01__OppPayment__c oldPayment = getFirstPayment(opp.Id);
        npe01__OppPayment__c newPayment = oldPayment.clone(true, false, false, false);
        newPayment.npe01__Paid__c = true;
        newPayment.npe01__Payment_Date__c = Date.newInstance(2026, 11, 20);
        Date closeDateBefore = [SELECT CloseDate FROM Opportunity WHERE Id = :opp.Id].CloseDate;

        Test.startTest();
        runHandler(npsp.TDTM_Runnable.Action.AfterUpdate, oldPayment, newPayment);
        Test.stopTest();

        Assert.areEqual(closeDateBefore, [SELECT CloseDate FROM Opportunity WHERE Id = :opp.Id].CloseDate, 'Marking a payment as Paid must leave the Close Date to the Closed Won update.');
    }

    //SFEUCMSD-134
    @isTest
    public static void setPaymentMethodFromRD_copiesTheRecurringDonationPaymentMethod() {
        Opportunity opp = createDonationOpp('Donor Donation 2026-11-05');
        npe01__OppPayment__c payment = new npe01__OppPayment__c(npe01__Opportunity__c = opp.Id, npe01__Payment_Amount__c = 10);

        Test.startTest();
        new PaymentTriggerService().setPaymentMethodFromRD(new List<npe01__OppPayment__c>{ payment });
        Test.stopTest();

        Assert.areEqual('Check', payment.npe01__Payment_Method__c, 'A new payment must take the payment method of its recurring donation.');
    }

    //SFEUCMSD-134
    @isTest
    public static void buildPayment_setsOpportunityAmountAndScheduledDate() {
        Opportunity opp = createDonationOpp('Donor Donation 2026-11-05');
        DonationRequest request = new DonationRequest();
        request.amount = 250;

        Test.startTest();
        npe01__OppPayment__c payment = PaymentTriggerService.buildPayment(request, opp.Id);
        Test.stopTest();

        Assert.areEqual(opp.Id, payment.npe01__Opportunity__c, 'The payment must belong to the opportunity.');
        Assert.areEqual(250, payment.npe01__Payment_Amount__c, 'The payment amount must come from the request.');
        Assert.areEqual(Date.today(), payment.npe01__Scheduled_Date__c, 'The scheduled date must be today.');
    }

    //SFEUCMSD-134
    @isTest
    public static void create_insertsThePayment() {
        Opportunity opp = createDonationOpp('Donor Donation 2026-11-05');
        DonationRequest request = new DonationRequest();
        request.amount = 250;

        Test.startTest();
        npe01__OppPayment__c payment = PaymentTriggerService.create(request, opp.Id);
        Test.stopTest();

        Assert.isNotNull(payment.Id, 'The payment must be inserted.');
        Assert.areEqual(250, [SELECT npe01__Payment_Amount__c FROM npe01__OppPayment__c WHERE Id = :payment.Id].npe01__Payment_Amount__c, 'The stored amount must come from the request.');
    }
}
