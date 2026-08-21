public class WSKentico {
    public String TransactionId { get; set; }
    public String TransactionDate { get; set; }	//Format yyyyMMddHHmmss
    public String FormType { get; set; }
    public String UserId { get; set; }
    public String Salutation { get; set; }
    public String FirstName { get; set; }
    public String LastName { get; set; }
    public String CompanyName { get; set; }
    public String AddressLine1 { get; set; }
    public String AddressLine2 { get; set; }
    public String AddressLine3 { get; set; }
    public String AddressLine4 { get; set; }
    public String AddressLine5 { get; set; }
    public String Zip { get; set; }
    public String City { get; set; }
    public String Region { get; set; }
    public String Country { get; set; }
    public String Email { get; set; }
    public String Phone { get; set; }
    public String PhoneArea { get; set; }
    public String AddressType { get; set; }
    public String Message { get; set; }
    public String Newsletter { get; set; }	// Values could be true/false/null
    public String FacerId { get; set; }
    public String FacerLocationId { get; set; }
    public String CampaignId { get; set; }
    public String DonationId { get; set; }
    public String Amount { get; set; }	// Format #.00
    public String CurrencyAmount { get; set; }
    public String ReferenceId { get; set; }
    public String CustomerId { get; set; }
    public String DonationType { get; set; }
    public String Preference { get; set; }
    public String Frequency { get; set; }
    public String PaymentType { get; set; }
    public String CreditCardHolder { get; set; }
    public String CreditCardNumber { get; set; }
    public String CreditCardExpiry { get; set; }
    public String CreditCardType { get; set; }
}