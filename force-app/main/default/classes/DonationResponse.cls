/**
 * Generic response returned to Kentico.
 */
//SFESWCSD-92
public class DonationResponse {
    public Boolean success;    
    public String status;
    public String message;
    public Id contactId;
    public Id accountId;
    public Id recurringDonationId;
    public Id opportunityId;
    public Id paymentId;    
    public Id donationId;
    public String recurringUUID;
}