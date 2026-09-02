/**
 * Service responsible for Account operations.
 */
public inherited sharing class AccountService {
    /**
     * Creates or updates an Account.
     */
    //SFESWCSD-92
    public static Account createOrUpdate(DonationRequest request) {

        Account existingAccount = findCorporateAccount(request);

        if (existingAccount != null) {
            return existingAccount;
        }

        Account account = buildAccount(request);

        insert account;

        return account;
    }

    /**
     * Builds a new Account.
     */
    private static Account buildAccount(
        DonationRequest request
    ) {

        Account account = new Account();

        account.Name = request.accountName;
        account.Email__c = request.email;
        account.Phone = request.phone;

        return account;
    }

    private static Account findCorporateAccount(DonationRequest request) {
        List<Account> accounts;
        Boolean hasEmail = String.isNotBlank(request.email);
        Boolean hasPhone = String.isNotBlank(request.phone);

        if (hasEmail && hasPhone) {
            accounts = [
                SELECT Id, Name, Email__c, Phone
                FROM Account
                WHERE Name = :request.accountName
                    AND (Email__c = :request.email OR Phone = :request.phone)
                LIMIT 1
            ];
        } else if (hasEmail) {
            accounts = [
                SELECT Id, Name, Email__c, Phone
                FROM Account
                WHERE Name = :request.accountName
                    AND Email__c = :request.email
                LIMIT 1
            ];
        } else if (hasPhone) {
            accounts = [
                SELECT Id, Name, Email__c, Phone
                FROM Account
                WHERE Name = :request.accountName
                    AND Phone = :request.phone
                LIMIT 1
            ];
        } else {
            return null;
        }

        return accounts.isEmpty() ? null : accounts[0];
    }

}