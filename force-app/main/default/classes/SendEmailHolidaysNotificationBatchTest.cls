@isTest
private class SendEmailHolidaysNotificationBatchTest {
static Contact createTestContact(String email, Date birthdate) {
        Contact c = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = email,
            Birthdate = birthdate,
            npsp__Do_Not_Contact__c = false,
            HasOptedOutOfEmail = false
        );
        insert c;
        return c;
    }

    @isTest
    static void testBirthdayEmailBatch() {
        Date today = Date.today();
        createTestContact('birthday@test.com', today);

        Test.startTest();
        SendEmailHolidaysNotificationBatch batch = new SendEmailHolidaysNotificationBatch(true);
        Database.executeBatch(batch, 1);
        Test.stopTest();
    }

    @isTest
    static void testHolidayEmailsBatchAllCases() {
        Test.startTest();
        
        for (Integer i = 1; i <= 5; i++) {
            String email = 'holiday' + i + '@test.com';
            Contact c = createTestContact(email, Date.newInstance(2000, 1, 1));
    
            SendEmailHolidaysNotificationBatch batch = new SendEmailHolidaysNotificationBatch(false);
            batch.testCase = i;
            batch.testEmail = email;
            Database.executeBatch(batch, 1);
        }        
        Test.stopTest();
    }

    @isTest
    static void testEmptyScope() {
        // Ensure start() returns no records
        Test.startTest();
        SendEmailHolidaysNotificationBatch batch = new SendEmailHolidaysNotificationBatch(true);
        Database.executeBatch(batch, 1);
        Test.stopTest();
    }

    @isTest
    static void testSchedulableInterface() {
        Test.startTest();
        SendEmailHolidaysNotificationBatch job = new SendEmailHolidaysNotificationBatch(false);
        String jobId = System.schedule('Test Holiday Job', '0 0 12 * * ?', job);
        Test.stopTest();
    }
}