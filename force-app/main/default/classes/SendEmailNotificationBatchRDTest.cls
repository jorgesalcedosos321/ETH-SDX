/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class SendEmailNotificationBatchRDTest {

    @isTest(SeeAllData=true)
    static void runTest() {
        // TO DO: implement unit test
        SendEmailNotificationBatch senb = new SendEmailNotificationBatch(Utils.REMINDER_3);
        senb.testStartDate = Datetime.now().addMonths(1);
        List<npe03__Recurring_Donation__c> recurringDonations = [SELECT Id, npe03__Contact__c
                FROM npe03__Recurring_Donation__c
                WHERE npe03__Contact__c != null
                AND Id IN (
                    SELECT npe03__Recurring_Donation__c
                    FROM Opportunity
                    WHERE StageName IN ('Declined', 'Missed', 'Closed Lost')
                )];
        senb.execute(null, recurringDonations);        
        Database.executeBatch(senb);
    }
}