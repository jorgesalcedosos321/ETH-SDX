/**
* @File Name : RecordTypeUtils.cls
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

public class RecordTypeUtils {   
    //
    public static String getRecordTypeId(String objectName, String recordTypeName){
        String id = NULL;
        if(objectName == 'Account'){
            id = Account.sObjectType.getDescribe().getRecordTypeInfosByName().get(recordTypeName).getRecordTypeId();
        }
        // else if(objectName == 'Contact'){
        //  id = Contact.sObjectType.getD escribe().getRecordTypeInfosByName().get(recordTypeName).getRecordTypeId();
        // }
        // else if(objectName == 'Lead'){
        //  id = Lead.sObjectType.getDescribe().getRecordTypeInfosByName().get(recordTypeName).getRecordTypeId();
        // }
        // else if(objectName == 'npe03__Recurring_Donation__c'){
        //  id = npe03__Recurring_Donation__c.sObjectType.getDescribe().getRecordTypeInfosByName().get(recordTypeName).getRecordTypeId();
        // }
        else if(objectName == 'Opportunity'){
            id = Opportunity.sObjectType.getDescribe().getRecordTypeInfosByName().get(recordTypeName).getRecordTypeId();
        }
        // else if(objectName == 'Campaign'){
        //  id = Campaign.sObjectType.getDescribe().getRecordTypeInfosByName().get(recordTypeName).getRecordTypeId();
        // }
        // else if(objectName == 'Active_History__c'){
        //  id = Active_History__c.sObjectType.getDescribe().getRecordTypeInfosByName().get(recordTypeName).getRecordTypeId();
        // }
        return id;
    }  
}