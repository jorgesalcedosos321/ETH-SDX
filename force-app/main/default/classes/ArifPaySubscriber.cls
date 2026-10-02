//SFESWCSD-92
public class ArifPaySubscriber {
    public String phoneNumber;
    public Datetime subscribedDate;
    public String status;
    public Decimal amount;
    public String recurringFrequency;
    public Datetime nextPaymentDate;
    public Integer maxRetryCount;
    public Integer retryIntervalHours;
    public Integer retryStartAfterPayments;
    public Integer failedAttempts;
    public Datetime lastNotifiedAt;
}
