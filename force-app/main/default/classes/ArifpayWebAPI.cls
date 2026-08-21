//SFESWCSD-74
@RestResource(urlMapping='/arifpay/chargeDonation')
global with sharing class ArifpayWebAPI {

    @HttpPost
    global static void createRecurring() {
        Map<String, Object> data = 
            (Map<String, Object>) JSON.deserializeUntyped(
                RestContext.request.requestBody.toString()
            );

        String email = (String) data.get('email');
        Decimal amount = Decimal.valueOf(String.valueOf(data.get('amount')));
        String airfpayId = (String) data.get('airfpayId');
        Date startDate = Date.valueOf((String) data.get('startDate'));

        Contact con;
        List<Contact> cons = [SELECT Id FROM Contact WHERE Email = :email LIMIT 1];

        if(cons.isEmpty()){
            con = new Contact(LastName = 'Donor', Email = email);
            INSERT con;
        } else {
            con = cons[0];
        }

        npe03__Recurring_Donation__c rd = new npe03__Recurring_Donation__c(
            npe03__Contact__c = con.Id,
            npe03__Amount__c = amount,
            npe03__Installment_Period__c = 'Monthly',
            npe03__Open_Ended_Status__c = 'Open',
            npe03__Next_Payment_Date__c = startDate,
            Arifpay_Transaction_Id__c = airfpayId
        );

        INSERT rd;
    }
}