//SFEUCMSD-146
@isTest
private class OpportunityHandler_TDTMTest {
    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'TDTM Handler Test');
        INSERT acc;
        Opportunity opp = new Opportunity(Name = 'TDTM Handler Donation', AccountId = acc.Id, StageName = 'Pledged', Amount = 100, CloseDate = Date.today().addMonths(1));
        INSERT opp;
    }

    private static npe01__OppPayment__c getPayment(Id oppId) {
        return [SELECT Id, npe01__Paid__c, npe01__Written_Off__c, status__c, npe01__Payment_Date__c FROM npe01__OppPayment__c WHERE npe01__Opportunity__c = :oppId ORDER BY CreatedDate LIMIT 1];
    }

    //SFEUCMSD-146 A trigger record carries every field, the other after update actions read several of them
    private static Opportunity getOpportunity() {
        List<String> fieldNames = new List<String>();
        for (Schema.SObjectField field : Opportunity.SObjectType.getDescribe().fields.getMap().values()) {
            if (field.getDescribe().isAccessible()) {
                fieldNames.add(field.getDescribe().getName());
            }
        }
        return Database.query('SELECT ' + String.join(fieldNames, ', ') + ' FROM Opportunity WHERE Name = \'TDTM Handler Donation\' LIMIT 1');
    }

    private static void runHandler(npsp.TDTM_Runnable.Action action, List<Opportunity> newRecords, List<Opportunity> oldRecords) {
        new OpportunityHandler_TDTM().run(newRecords, oldRecords, action, Opportunity.SObjectType.getDescribe());
    }

    @isTest
    static void afterUpdate_closedWon_marksPaymentsPaid() {
        Opportunity opp = getOpportunity();
        Opportunity oldOpp = opp.clone(true, false, false, false);
        Opportunity newOpp = opp.clone(true, false, false, false);
        newOpp.StageName = 'Closed Won';

        Test.startTest();
        runHandler(npsp.TDTM_Runnable.Action.AfterUpdate, new List<Opportunity>{ newOpp }, new List<Opportunity>{ oldOpp });
        Test.stopTest();

        npe01__OppPayment__c payment = getPayment(opp.Id);
        Assert.isTrue(payment.npe01__Paid__c, 'Closed Won must tick Paid on the payments.');
        Assert.areEqual('Paid', payment.status__c, 'Closed Won must set the payment status to Paid.');
        Assert.isNotNull(payment.npe01__Payment_Date__c, 'Closed Won must set a Payment Date.');
    }

    @isTest
    static void afterUpdate_declined_writesOffPayments() {
        Opportunity opp = getOpportunity();
        Opportunity oldOpp = opp.clone(true, false, false, false);
        Opportunity newOpp = opp.clone(true, false, false, false);
        newOpp.StageName = 'Declined';

        Test.startTest();
        runHandler(npsp.TDTM_Runnable.Action.AfterUpdate, new List<Opportunity>{ newOpp }, new List<Opportunity>{ oldOpp });
        Test.stopTest();

        npe01__OppPayment__c payment = getPayment(opp.Id);
        Assert.isTrue(payment.npe01__Written_Off__c, 'Declined must tick Written Off on the payments.');
        Assert.areEqual('Failed', payment.status__c, 'Declined must set the payment status to Failed.');
    }

    @isTest
    static void insertActions_runWithoutChangingThePayments() {
        Opportunity opp = getOpportunity();
        Opportunity newOpp = new Opportunity(Name = 'TDTM Handler New', AccountId = opp.AccountId, StageName = 'Pledged', Amount = 50, CloseDate = Date.today());

        Test.startTest();
        runHandler(npsp.TDTM_Runnable.Action.BeforeInsert, new List<Opportunity>{ newOpp }, null);
        runHandler(npsp.TDTM_Runnable.Action.AfterInsert, new List<Opportunity>{ opp }, null);
        Test.stopTest();

        npe01__OppPayment__c payment = getPayment(opp.Id);
        Assert.isFalse(payment.npe01__Paid__c, 'The insert actions must not pay the payment.');
        Assert.isFalse(payment.npe01__Written_Off__c, 'The insert actions must not write the payment off.');
    }
}
