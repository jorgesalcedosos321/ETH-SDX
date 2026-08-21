@isTest
private class DPOUtilsTest {
    @testSetup()
    static void setupData() {
        DPOUtils.setDPOCredentials();
    }
	@isTest
    static void testValidateAndConvertToDateTime() {
        // Valid datetime string
        String validDateTime = '20250219123045';
        DateTime result = DPOUtils.validateAndConvertToDateTime(validDateTime);
        System.assertNotEquals(result, null, 'Valid datetime string should return a DateTime value');
        System.assertEquals(result.year(), 2025, 'Year should be 2025');
        System.assertEquals(result.month(), 2, 'Month should be 2');
        System.assertEquals(result.day(), 19, 'Day should be 19');
        System.assertEquals(result.hour(), 12, 'Hour should be 12');
        System.assertEquals(result.minute(), 30, 'Minute should be 30');
        System.assertEquals(result.second(), 45, 'Second should be 45');

        // Invalid datetime string (wrong length)
        String invalidDateTime = '20250219123'; // Too short
        DateTime invalidResult = DPOUtils.validateAndConvertToDateTime(invalidDateTime);
        System.assertEquals(invalidResult, null, 'Invalid datetime string should return null');

        // Invalid datetime string (non-numeric)
        String invalidDateTime2 = '2025xx19123045';
        DateTime invalidResult2 = DPOUtils.validateAndConvertToDateTime(invalidDateTime2);
        System.assertEquals(invalidResult2, null, 'Invalid datetime string should return null');

        // Empty string
        String emptyDateTime = '';
        DateTime emptyResult = DPOUtils.validateAndConvertToDateTime(emptyDateTime);
        System.assertEquals(emptyResult, null, 'Empty datetime string should return null');
    }
    
    @isTest
    static void testValidateAndConvertToDate_ValidInput() {
        // Test case for valid Date string in "yyyyMMdd" format
        String validDateStr = '20250219';
        Date result = DPOUtils.validateAndConvertToDate(validDateStr);

        // Assert that the result is not null
        System.assertNotEquals(result, null, 'The result should not be null');
        
        // Assert that the Date is correct
        Date expectedDate = Date.newInstance(2025, 2, 19);
        System.assertEquals(result, expectedDate, 'The Date values should match');
    }

    @isTest
    static void testValidateAndConvertToDate_InvalidInput() {
        // Test case for invalid Date string
        String invalidDateStr = '202502AB'; // Contains invalid characters
        Date result = DPOUtils.validateAndConvertToDate(invalidDateStr);

        // Assert that the result is null
        System.assertEquals(result, null, 'The result should be null for invalid input');
    }

    @isTest
    static void testValidateAndConvertToDate_EmptyInput() {
        // Test case for empty string input
        String emptyDateStr = '';
        Date result = DPOUtils.validateAndConvertToDate(emptyDateStr);

        // Assert that the result is null
        System.assertEquals(result, null, 'The result should be null for empty input');
    }

    @isTest
    static void testValidateAndConvertToDate_NullInput() {
        // Test case for null input
        Date result = DPOUtils.validateAndConvertToDate(null);

        // Assert that the result is null
        System.assertEquals(result, null, 'The result should be null for null input');
    }
}