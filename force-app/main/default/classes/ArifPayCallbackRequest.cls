/**
 * Callback received from ArifPay.
 */
//SFESWCSD-92
public class ArifPayCallbackRequest {
    public String donationId;
    public String recurringUUID;
    public String paymentStatus;
    public Decimal amount;
    public Date transactionDate;
    public String referenceId;
    public String paymentMethod;
    public String cardHolder;
    public String cardNetwork;
    public String creditCardType;
    public String cardLast4;
    public String cardLast4Digits;
    public Integer expiryMonth;
    public Integer expiryYear;
    public Integer cardExpiryMonth;
    public Integer cardExpiryYear;
    public String currencyEN;
}