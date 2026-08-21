/**
* @File Name : RecordTypeUtilsTest.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : October 26, 2024
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | October 26, 2024 |   | Initial Version
**/

@isTest
private class RecordTypeUtilsTest {
	@isTest 
    public static void checkEachRT(){
		Id rt1 = RecordTypeUtils.getRecordTypeId('Account', 'Organization');
		//Id rt2 = RecordTypeUtils.getRecordTypeId('Contact', '');
		//Id rt3 = RecordTypeUtils.getRecordTypeId('Lead', '');
		//Id rt4 = RecordTypeUtils.getRecordTypeId('npe03__Recurring_Donation__c', '');
		Id rt5 = RecordTypeUtils.getRecordTypeId('Opportunity', 'Donation');
		//Id rt6 = RecordTypeUtils.getRecordTypeId('Campaign', '');
	}
}