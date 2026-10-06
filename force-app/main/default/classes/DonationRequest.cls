/**
 * DTO used by Kentico to send Prospect and Donation requests.
 */
//SFESWCSD-92
public class DonationRequest {
    // Transaction
    public String formType; //transactionType       // Prospect | Donation
    public String donorType;             // Individual | Corporate
    public String donationType;          // OneOff | Recurring | Sponsorship
    public String donationId;

    // Sponsorship
    public String sponsorshipType;
    public String sponsorshipCategory;
    public String villageSelection;
    public String age;
    public String preference;//sponsorshipPreference
    public String sponsorshipId;

    // Donation
    public Decimal amount; //donationAmount
    public String frequency;
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
    public String city;
    public String country;
    public String addressLine1; //mailingStreet
    public String region; //mailingState
    public String zip; //mailingPostalCode

    // Organization
    public String companyName;

    // Consent
    public Boolean emailOptOut;
    public Boolean personalDataConsent;
    public Boolean childDataSafeguarding;

    // Campaign
    public String campaignId;
    public String donationGuid;//recurringUUID
    public String referenceId;

    // Payment
    public String paymentMethod;
    public String paymentType;

    // Misc
    public String source;
}