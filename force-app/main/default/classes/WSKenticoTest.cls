@isTest
private class WSKenticoTest {

    @isTest
    static void testWSKenticoProperties() {
        // Create instance and set all fields
        WSKentico kentico = new WSKentico();
        kentico.TransactionId = 'TX123';
        kentico.TransactionDate = '20250419123000';
        kentico.FormType = 'Donation';
        kentico.UserId = 'User123';
        kentico.Salutation = 'Mr.';
        kentico.FirstName = 'John';
        kentico.LastName = 'Doe';
        kentico.CompanyName = 'OpenAI';
        kentico.AddressLine1 = '123 Street';
        kentico.AddressLine2 = 'Apt 4';
        kentico.AddressLine3 = 'Building B';
        kentico.AddressLine4 = 'Level 5';
        kentico.AddressLine5 = 'Unit 10';
        kentico.Zip = '12345';
        kentico.City = 'AI City';
        kentico.Region = 'AI Region';
        kentico.Country = 'US';
        kentico.Email = 'john.doe@example.com';
        kentico.Phone = '1234567890';
        kentico.PhoneArea = '555';
        kentico.AddressType = 'Home';
        kentico.Message = 'Support AI';
        kentico.Newsletter = 'true';
        kentico.FacerId = 'F123';
        kentico.FacerLocationId = 'FL456';
        kentico.CampaignId = 'CMP789';
        kentico.DonationId = 'D123';
        kentico.Amount = '100.00';
        kentico.CurrencyAmount = 'USD';
        kentico.ReferenceId = 'REF987';
        kentico.CustomerId = 'CUST456';
        kentico.DonationType = 'One-time';
        kentico.Preference = 'Email';
        kentico.Frequency = 'Monthly';
        kentico.PaymentType = 'Credit Card';
        kentico.CreditCardHolder = 'John Doe';
        kentico.CreditCardNumber = '4111111111111111';
        kentico.CreditCardExpiry = '12/2025';
        kentico.CreditCardType = 'Visa';

        // Minimal assertion to verify data was stored properly
        System.assertEquals('TX123', kentico.TransactionId);
        System.assertEquals('John', kentico.FirstName);
        System.assertEquals('Doe', kentico.LastName);
        System.assertEquals('Visa', kentico.CreditCardType);
    }
}