@IsTest
private class AccountServiceTest {
    @IsTest
    static void reusesCorporateAccountByNameAndEmail() {
        Account existingAccount = new Account(
            Name = 'Existing Corporate Email',
            Email__c = 'corporate@example.com',
            Phone = '111111111'
        );
        insert existingAccount;

        DonationRequest request = corporateRequest(
            existingAccount.Name,
            existingAccount.Email__c,
            '999999999'
        );

        Account result = AccountService.createOrUpdate(request);

        Assert.areEqual(existingAccount.Id, result.Id);
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Account WHERE Name = :existingAccount.Name]
        );
    }

    @IsTest
    static void reusesCorporateAccountByNameAndPhone() {
        Account existingAccount = new Account(
            Name = 'Existing Corporate Phone',
            Email__c = 'old@example.com',
            Phone = '222222222'
        );
        insert existingAccount;

        DonationRequest request = corporateRequest(
            existingAccount.Name,
            'new@example.com',
            existingAccount.Phone
        );

        Account result = AccountService.createOrUpdate(request);

        Assert.areEqual(existingAccount.Id, result.Id);
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Account WHERE Name = :existingAccount.Name]
        );
    }

    @IsTest
    static void createsCorporateAccountWhenNoMatchExists() {
        DonationRequest request = corporateRequest(
            'New Corporate Account',
            'new-corporate@example.com',
            '333333333'
        );

        Account result = AccountService.createOrUpdate(request);
        Account createdAccount = [
            SELECT Name, Email__c, Phone
            FROM Account
            WHERE Id = :result.Id
        ];

        Assert.areEqual(request.accountName, createdAccount.Name);
        Assert.areEqual(request.email, createdAccount.Email__c);
        Assert.areEqual(request.phone, createdAccount.Phone);
    }

    @IsTest
    static void createsCorporateAccountWithoutOptionalIdentifiers() {
        DonationRequest request = corporateRequest(
            'Corporate Without Identifiers',
            null,
            null
        );

        Account result = AccountService.createOrUpdate(request);

        Assert.areEqual(request.accountName, result.Name);
    }

    private static DonationRequest corporateRequest(
        String accountName,
        String email,
        String phone
    ) {
        DonationRequest request = new DonationRequest();
        request.donorType = ApiConstants.DONOR_CORPORATE;
        request.accountName = accountName;
        request.email = email;
        request.phone = phone;
        return request;
    }
}