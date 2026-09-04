// Use .apex files to store anonymous Apex.
// You can execute anonymous Apex in VS Code by selecting the
//     apex text and running the command:
//     SFDX: Execute Anonymous Apex with Currently Selected Text
// You can also execute the entire file by running the command:
//     SFDX: Execute Anonymous Apex with Editor Contents

//string tempvar = 'Enter_your_name_here';
//System.debug('Hello World!');
// System.debug('My name is ' + tempvar);

// Contact c = new Contact(Firstname='Jorge Test DLC', lastname='Salcedo Test DLC', Email='jorge.salcedo321@gmail.com');
// INSERT c;

Contact cnt = [SELECT Id, Name FROM Contact WHERE Email = 'jorge.salcedo321@gmail.com' ORDER BY CreatedDate DESC LIMIT 1];
// Transaction finalTransaction = new Transaction();
npe03__Recurring_Donation__c rd =
            new npe03__Recurring_Donation__c(
                npe03__Contact__c = cnt.Id,
                npe03__Amount__c = 25,
                npsp__Day_of_Month__c = '1',
                npe03__Installment_Period__c = ApiConstants.PERIOD_MONTHLY,
                npe03__Open_Ended_Status__c = 'Open',
                npsp__Status__c = 'Active',
                Donor_Type__c = ApiConstants.DONOR_INDIVIDUAL,
                Donation_Type__c = ApiConstants.DONATION_SPONSORSHIP
            );
        insert rd;

System.Savepoint sp = Database.setSavepoint();
try {

}catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
}finally {
    Database.rollback(sp);
}