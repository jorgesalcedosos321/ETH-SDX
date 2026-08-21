/**
 * DTO used by Kentico to send Prospect and Donation requests.
 */
//SFESWCSD-92
public class DonationRequest {
    // Transaction
    public String transactionType;       // Prospect | Donation
    public String donorType;             // Individual | Corporate
    public String donationType;          // OneOff | Recurring | Sponsorship
    public String donationId;

    // Sponsorship
    public String sponsorshipType;
    public String sponsorshipCategory;
    public String sponsorshipLocation;
    public String sponsorshipAgePreference;
    public String sponsorshipPreference;
    public String sponsorshipId;

    // Donation
    public Decimal amount;
    public String installmentPeriod;
    public Date dateEstablished;

    // Contact
    public String salutation;
    public String firstName;
    public String lastName;
    public String email;
    public String phone;
    public Date birthday;
    public String gender;

    // Address
    public String mailingStreet;
    public String mailingCity;
    public String mailingState;
    public String mailingPostalCode;
    public String mailingCountry;

    // Organization
    public String accountName;

    // Consent
    public Boolean emailOptOut;
    public Boolean personalDataConsent;
    public Boolean childDataSafeguarding;

    // Campaign
    public String campaign;
    public String recurringUUID;

    // Payment
    public String paymentMethod;
    public String paymentType;

    // Misc
    public String source;
}