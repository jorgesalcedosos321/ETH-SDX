@IsTest
private class RecurringDonationHandler_TDTMTest {

    @IsTest
    static void run_coversAllTriggerActions() {
        RecurringDonationHandler_TDTM handler = new RecurringDonationHandler_TDTM();
        Schema.DescribeSObjectResult rdDescribe = npe03__Recurring_Donation__c.SObjectType.getDescribe();

        Contact donor = createContact('009');
        Campaign campaign = createCampaign('009');
        List<npe03__Recurring_Donation__c> beforeInsertRDs = new List<npe03__Recurring_Donation__c>{
                buildBeforeInsertRD(donor, campaign)
        };
        Id updatedRdId = Id.valueOf(rdDescribe.getKeyPrefix() + '000000000001');
        List<npe03__Recurring_Donation__c> beforeUpdateNewRDs = new List<npe03__Recurring_Donation__c>{
                new npe03__Recurring_Donation__c(Id = updatedRdId, npsp__Status__c = 'Closed')
        };
        List<npe03__Recurring_Donation__c> beforeUpdateOldRDs = new List<npe03__Recurring_Donation__c>{
                new npe03__Recurring_Donation__c(Id = updatedRdId, npsp__Status__c = 'Active')
        };

        Test.startTest();
        npsp.TDTM_Runnable.DmlWrapper beforeInsertWrapper = handler.run(
                toSObjects(beforeInsertRDs),
                toSObjects(new List<npe03__Recurring_Donation__c>()),
                npsp.TDTM_Runnable.Action.BeforeInsert,
                rdDescribe
        );
        npsp.TDTM_Runnable.DmlWrapper afterInsertWrapper = handler.run(
                toSObjects(new List<npe03__Recurring_Donation__c>()),
                toSObjects(new List<npe03__Recurring_Donation__c>()),
                npsp.TDTM_Runnable.Action.AfterInsert,
                rdDescribe
        );
        npsp.TDTM_Runnable.DmlWrapper afterUpdateWrapper = handler.run(
                toSObjects(new List<npe03__Recurring_Donation__c>()),
                toSObjects(new List<npe03__Recurring_Donation__c>()),
                npsp.TDTM_Runnable.Action.AfterUpdate,
                rdDescribe
        );
        npsp.TDTM_Runnable.DmlWrapper beforeUpdateWrapper = handler.run(
                toSObjects(beforeUpdateNewRDs),
                toSObjects(beforeUpdateOldRDs),
                npsp.TDTM_Runnable.Action.BeforeUpdate,
                rdDescribe
        );
        Test.stopTest();

        System.assertNotEquals(null, beforeInsertWrapper, 'BeforeInsert should return a DmlWrapper.');

        assertNoObjectsToUpdate(afterInsertWrapper, 'AfterInsert');
        assertNoObjectsToUpdate(afterUpdateWrapper, 'AfterUpdate');
        System.assertNotEquals(null, beforeUpdateWrapper, 'BeforeUpdate should return a DmlWrapper.');
    }

    private static Contact createContact(String suffix) {
        Contact donor = new Contact(
                FirstName = 'TDTM',
                LastName = 'Recurring Donor ' + suffix
        );
        insert donor;

        donor = [
                SELECT Id, AccountId
                FROM Contact
                WHERE Id = :donor.Id
        ];

        if (donor.AccountId == null) {
            Account household = new Account(Name = 'TDTM Household ' + suffix);
            insert household;
            donor.AccountId = household.Id;
            update donor;
        }

        return donor;
    }

    private static Campaign createCampaign(String suffix) {
        Campaign campaign = new Campaign(
                Name = 'TDTM RD Campaign ' + suffix,
                Campaign_ID__c = 'C' + suffix
        );
        insert campaign;
        return campaign;
    }

    private static npe03__Recurring_Donation__c buildBeforeInsertRD(Contact donor, Campaign campaign) {
        Contact donorWithName = [
                SELECT Id, Name
                FROM Contact
                WHERE Id = :donor.Id
        ];
        Account donorAccount = [
                SELECT Id, Name, npe01__SYSTEMIsIndividual__c
                FROM Account
                WHERE Id = :donor.AccountId
        ];

        npe03__Recurring_Donation__c rd = new npe03__Recurring_Donation__c(
                Name = 'TDTM Before Insert RD',
                npe03__Contact__c = donor.Id,
                npe03__Organization__c = donor.AccountId,
                npe03__Amount__c = 25,
                npe03__Installment_Period__c = 'Monthly',
                npsp__RecurringType__c = 'Open',
                npsp__Day_of_Month__c = String.valueOf(Date.today().day()),
                npe03__Date_Established__c = Date.today(),
                npe03__Next_Payment_Date__c = Date.today().addMonths(1),
                npsp__Status__c = 'Active',
                npe03__Recurring_Donation_Campaign__c = campaign.Id
        );
        rd.npe03__Contact__r = donorWithName;
        rd.npe03__Organization__r = donorAccount;
        return rd;
    }

    private static List<SObject> toSObjects(List<npe03__Recurring_Donation__c> recurringDonations) {
        List<SObject> records = new List<SObject>();
        for (npe03__Recurring_Donation__c rd : recurringDonations) {
            records.add(rd);
        }
        return records;
    }

    private static void assertNoObjectsToUpdate(npsp.TDTM_Runnable.DmlWrapper wrapper, String actionName) {
        System.assertNotEquals(null, wrapper, actionName + ' should return a DmlWrapper.');
        System.assertEquals(0, wrapper.objectsToUpdate.size(), actionName + ' should not request recurring donation updates.');
    }
}