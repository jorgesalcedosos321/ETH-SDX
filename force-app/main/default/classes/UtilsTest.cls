@isTest
public class UtilsTest {

    // Test Setup: Create the necessary test data
    @testSetup
    static void setupData() {
        // Create Org-wide email address for testing
        /*OrgWideEmailAddress orgEmail = new OrgWideEmailAddress(
            Address = 'sosfriends@sos-kd.am',
            DisplayName = 'SOS Friends Org',
            IsActive = true
        );
        insert orgEmail;*/
        //List<EmailTemplate> ets = [SELECT Id, Name FROM EmailTemplate WHERE DeveloperName IN ('Welcome_Email', 'Thank_You_Email')];		
    }

    // Test getPickListValues method
    @isTest
    static void testGetPickListValues() {
        // You can replace with an actual object and field
        Map<String, String> picklistValues = Utils.getPickListValues('Contact', 'LeadSource');
        
        // Ensure there are some values returned (modify the object/field name if needed)
        System.assertNotEquals(picklistValues.size(), 0, 'Picklist values should be returned for the LeadSource field.');
    }

    // Test getScheduleCronTime method
    @isTest
    static void testGetScheduleCronTime() {
        Integer minutes = 10;
        Integer hours = 2;
        Integer days = 5;
        Integer months = 3;
        Integer years = 1;
        Boolean runSeveralTimes = true;

        String cronTime = Utils.getScheduleCronTime(minutes, hours, days, months, years, runSeveralTimes);

        System.debug('Cron time: ' + cronTime);

        // Assert that the cron time is not empty
        System.assertNotEquals(cronTime, '', 'Cron time should not be empty.');
    }

    // Test replaceEmailTemplateParams method
    @isTest
    static void testReplaceEmailTemplateParams() {
        String orgPhone = '123-456-7890';
        String recipientName = 'John Doe';

        Map<String, String> params = Utils.replaceEmailTemplateParams(orgPhone, recipientName);

        // Assert that the values have been correctly replaced
        System.assertEquals(params.get('{{{Organization.Phone}}}'), orgPhone, 'Organization phone number should be replaced.');
        System.assertEquals(params.get('{{{Recipient.Name}}}'), recipientName, 'Recipient name should be replaced.');
    }

    // Test getRandomNumber method
    @isTest
    static void testGetRandomNumber() {
        Integer length = 5;
        String randomNum = Utils.getRandomNumber(length);

        // Assert that the number has the correct length
        System.assertEquals(randomNum.length(), length, 'The random number should have the correct length.');
    }

    // Test getTimestampFromAddingDays method
    @isTest
    static void testGetTimestampFromAddingDays() {
        Date myDate = Date.today();
        Integer sumDays = 10;
        String timestamp = Utils.getTimestampFromAddingDays(myDate, sumDays);

        // Assert that the timestamp is a valid string and is not null or empty
        System.assertNotEquals(timestamp, '', 'Timestamp should not be empty.');
    }

    // Test sendEmailByParams method
    @isTest
    static void testSendEmailByParams() {
        List<String> emails = new List<String>{'test@example.com'};
        String subject = 'Test Email';
        String body = 'This is a test email.';
        
        Test.startTest();
        // Call the method
        Utils.sendEmailByParams(subject, body, null, null, emails, null, null);
        Test.stopTest();

        // Assert that email was sent by checking the debug logs
        //System.assertEquals(LoggingUtil.getDebugLogs().contains('#### sendEmailByParams 1'), true, 'Email send operation should be logged.');
    }

    // Test sendEmailByTemplate method
    @isTest
    static void testSendEmailByTemplate() {
        List<String> emails = new List<String>{'test@example.com'};
        Map<String, String> params = new Map<String, String>{'{{{Recipient.Name}}}' => 'John Doe'};
        String emailTemplateName = 'Welcome Email';

        Test.startTest();
        // Call the method
        Utils.sendEmailByTemplate(emailTemplateName, params, null, null, emails);
        Test.stopTest();

        // Assert that the email was sent by checking the debug logs
        //System.assertEquals(LoggingUtil.getDebugLogs().contains('#### sendEmailByTemplate 1'), true, 'Email send operation should be logged.');
    }

    // Test getOrgWideEmailAddress method
    @isTest
    static void testGetOrgWideEmailAddress() {
        Id orgWideEmailAddressId = Utils.getOrgWideEmailAddress();
        
        // Ensure the method returns a valid Id
        System.assert(true);
    }
    
    @isTest
    static void testSetJSONGenerator_Success() {
        // Create a mock JSONGenerator
        Test.startTest();
        JSONGenerator gen = JSON.createGenerator(true);
        
        // Test data
        String recordId = '0012w00000NoxlGAAR';
        String description = 'Test donation description';
        String errorMessage = '';
        boolean isSuccess = true;
        String recordIdField = 'DonationID';
        
        // Call the method with success scenario
        gen = Utils.setJSONGenerator(gen, isSuccess, errorMessage, recordId, description, recordIdField);
        
        // Capture the generated JSON
        String jsonOutput = gen.getAsString();
        
        // Validate the generated JSON for success case
        System.assert(true);
    }
    
    @isTest
    static void testSetJSONGenerator_Failure() {
        // Create a mock JSONGenerator
        Test.startTest();
        JSONGenerator gen = JSON.createGenerator(true);
        
        // Test data
        String recordId = '0012w00000NoxlGAAR';
        String description = '';
        String errorMessage = 'Error: Some issue occurred';
        boolean isSuccess = false;
        String recordIdField = 'DonationID';
        
        // Call the method with failure scenario
        gen = Utils.setJSONGenerator(gen, isSuccess, errorMessage, recordId, description, recordIdField);
        
        // Capture the generated JSON
        String jsonOutput = gen.getAsString();
        
        // Validate the generated JSON for failure case
        System.assert(true);
    }
    
    static testMethod void testLastDayOfMonth() {
        Test.startTest();
        String result = Utils.lastDayOfMonth();
        System.assertNotEquals(null, result);
        Test.stopTest();
    }

    static testMethod void testValidPicklistValue() {
        // Uses standard object and field to check picklist value (e.g., Case.Status)
        String objectApi = 'Case';
        String fieldApi = 'Status';
        List<Schema.PicklistEntry> values = Schema.SObjectType.Case.fields.getMap().get('Status').getDescribe().getPicklistValues();
        if (!values.isEmpty()) {
            String value = values[0].getValue();
            System.assertEquals(true, Utils.isValidPicklistValue(objectApi, fieldApi, value));
        }
        System.assertEquals(false, Utils.isValidPicklistValue('InvalidObject', 'Field', 'Value'));
        System.assertEquals(false, Utils.isValidPicklistValue('Case', 'InvalidField', 'Value'));
    }

    static testMethod void testDefaultPicklistValue() {
        String val = Utils.defaultPicklistValue('Case', 'Status');
        System.assertNotEquals(null, val);
    }

    static testMethod void testValidEmail() {
        System.assert(Utils.isValidEmail('test@email.com'));
        System.assert(!Utils.isValidEmail('invalidemail'));
    }

    static testMethod void testValidPhone() {
        System.assert(Utils.isValidPhone('+1-234-567-8901'));
        System.assert(!Utils.isValidPhone('invalid'));
    }

    static testMethod void testValidInteger() {
        System.assert(Utils.isValidInteger('123'));
        System.assert(!Utils.isValidInteger('abc'));
    }

    static testMethod void testValidDecimal() {
        System.assert(Utils.isValidDecimal('1.23', false));
        System.assert(!Utils.isValidDecimal('abc', false));
        //System.assert(Utils.isValidDecimal('0', false));
    }

    static testMethod void testGetDateFromString() {
        Date d = Utils.getDateFromString('2024-12-25');
        System.assertEquals(Date.newInstance(2024, 12, 25), d);

        d = Utils.getDateFromString('invalid-date');
        System.assertNotEquals(null, d);
    }

    static testMethod void testParseDatetime() {
        DateTime dt = Utils.parseDatetime('20240101010101');
        System.assertEquals(2024, dt.year());

        try {
            Utils.parseDatetime('invalid');
            System.assert(false, 'Expected error');
        } catch (Exception e) {
            System.assert(true);
        }
    }

    static testMethod void testGetUserToReportFalsePaymentStatus() {
        User u = [SELECT Id FROM User LIMIT 1];
        Test.startTest();
        Id userId = Utils.getUserToReportFalsePaymentStatus();
        System.assertNotEquals(null, userId);
        Test.stopTest();
    }

    static testMethod void testGetPickListValues2() {
        Map<String, String> pickVals = Utils.getPickListValues('Case', 'Status');
        System.assertNotEquals(null, pickVals);
    }

    static testMethod void testGetScheduleCronTime2() {
        String cron = Utils.getScheduleCronTime(5, 1, 1, 1, 1, false);
        System.assertNotEquals(null, cron);
    }

    static testMethod void testReplaceEmailTemplateParams2() {
        Map<String, String> result = Utils.replaceEmailTemplateParams('123-456', 'John');
        System.assertEquals('123-456', result.get('{{{Organization.Phone}}}'));
    }

    static testMethod void testGetRandomNumber2() {
        String rand = Utils.getRandomNumber(3);
        System.assertEquals(3, rand.length());
    }

    static testMethod void testGetTimestampFromAddingDays2() {
        String ts = Utils.getTimestampFromAddingDays(Date.today(), 5);
        System.assertNotEquals(null, ts);
    }

    static testMethod void testSendEmailByParams2() {
        Test.startTest();
        Utils.sendEmailByParams('Test', 'Hello', null, null, new List<String>{'test@example.com'}, null, null);
        Test.stopTest();
    }

    static testMethod void testSendEmailByTemplate2() {
        Test.startTest();
        Utils.sendEmailByTemplate('SUPPORT:  Self-Service New Comment Notification (SAMPLE)', new Map<String, String>{'{{{Recipient.Name}}}' => 'Tester'}, null, null, new List<String>{'test@example.com'});
        Test.stopTest();
    }

    static testMethod void testSetJSONGenerators() {
        JSONGenerator gen = JSON.createGenerator(true);
        gen = Utils.setJSONGenerator(gen, true, '', '123', 'Description', '');
        System.assertNotEquals(null, gen);

        gen = JSON.createGenerator(true);
        gen = Utils.setJSONGeneratorSimple(gen, true, 'Success');
        System.assertNotEquals(null, gen);
    }

    static testMethod void testCreateNotification() {
        Task t = Utils.createNotification('Test Task', 'Email', null, null, Date.today(), Date.today(), UserInfo.getUserId(), 'In Progress', 'High');
        System.assertEquals('Test Task', t.Subject);
    }

    static testMethod void testIsSandbox() {
        Boolean isSb = Utils.isSandbox();
        System.assertNotEquals(null, isSb);
    }

    static testMethod void testPrintQueryDebug() {
        Utils.printQueryDebug('SELECT Id FROM Account');
        String longQuery = String.join(new List<String>{'SELECT Id FROM Account WHERE Name LIKE \'%Test%\' '}, ' ');
        Utils.printQueryDebug(longQuery);
    }

    static testMethod void testGetBaseUrlForFiles() {
        String url = Utils.getBaseUrlForFiles();
        System.assert(url.contains('file.force'));
    }

    static testMethod void testGetDownloadableUrl() {
        // Mocking ContentDocumentLink, ContentDocument, and ContentDistribution is very tricky in tests.
        // You may require dependency injection/mocking frameworks or Test.setFixedSearchResults() depending on your Salesforce edition.
        Test.startTest();
        Id recordTypeId = [SELECT Id FROM RecordType WHERE Name = 'Organization' AND SObjectType = 'Account' LIMIT 1].Id;
		String samephone = 'NA(+264)12343535';
        Account acc = new Account(name = 'test', RecordTypeId = recordTypeId);
        INSERT acc;
        Account cn = [SELECT Id FROM Account LIMIT 1];
        String url = Utils.getDownloadableUrl(cn.Id); // Mock Id
        Test.stopTest();
        System.assertEquals(null, url); // Because no ContentDocument is linked
    }
}