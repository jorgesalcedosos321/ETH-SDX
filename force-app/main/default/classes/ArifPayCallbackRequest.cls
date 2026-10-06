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
    public String transactionId; //referenceId
    public String paymentMethod;
    public String creditCardHolder; //cardHolder
    public String cardNetwork;
    public String creditCardType;
    public String cardLast4;
    public String creditCardNumber; //cardLast4Digits
    // public Integer expiryMonth;
    // public Integer expiryYear;
    public String creditCardExpiry; //CreditCardExpiry
    public String currencyEN;

    public Integer cardExpiryMonth {
        get {
            Integer parsed = parseCardExpiry(true);
            return parsed;
        }
    }

    public Integer cardExpiryYear {
        get {
            Integer parsed = parseCardExpiry(false);
            return parsed;
        }
    }

    /**
     * Reads cardExpiry (format MMyy, e.g. "1228") and returns the month (12) when isMonth
     * is true, or the four-digit year (2028) otherwise. Returns null when blank or malformed.
     */
    public Integer parseCardExpiry(Boolean isMonth) {
        if (String.isBlank(creditCardExpiry)) {
            return null;
        }
        String value = creditCardExpiry.trim();
        if (value.length() != 4 || !value.isNumeric()) {
            return null;
        }
        Integer month = Integer.valueOf(value.substring(0, 2));
        if (month < 1 || month > 12) {
            return null;
        }
        return isMonth ? month : 2000 + Integer.valueOf(value.substring(2, 4));
    }
}