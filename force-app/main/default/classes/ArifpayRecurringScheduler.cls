//SFESWCSD-74
global class ArifpayRecurringScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {
        List<Opportunity> opps = [
            SELECT Id, Amount, CloseDate,
                   npe03__Recurring_Donation__r.Arifpay_Transaction_Id__c
            FROM Opportunity
            WHERE StageName = 'Pledged'
            AND CloseDate = TODAY
            AND npe03__Recurring_Donation__c != NULL
        ];

        for(Opportunity opp : opps){
            try {
                ArifpayService.charge(
                    opp.npe03__Recurring_Donation__r.Arifpay_Transaction_Id__c,
                    opp.Amount
                );

                // Mark as paid
                opp.StageName = 'Closed Won';

            } catch(Exception e){
                System.debug('Payment failed: ' + e.getMessage());
            }
        }

        update opps;
    }
}