/**
 * Service responsible for Account operations.
 */
public inherited sharing class AccountService {
    /**
     * Creates or updates an Account.
     */
    //SFESWCSD-92
    public static Account createOrUpdate(
        DonationRequest request,
        Contact contact
    ) {

        if (contact.AccountId != null) {
            return [
                SELECT Id, Name
                FROM Account
                WHERE Id = :contact.AccountId
                LIMIT 1
            ];
        }

        Account account = buildAccount(request);

        insert account;

        contact.AccountId = account.Id;
        update contact;

        return account;
    }

    /**
     * Builds a new Account.
     */
    private static Account buildAccount(
        DonationRequest request
    ) {

        Account account = new Account();

        if (request.donorType == ApiConstants.DONOR_CORPORATE) {
            account.Name = request.accountName;
        } else {
            account.Name =
                request.firstName + ' ' + request.lastName;
        }

        return account;
    }

}