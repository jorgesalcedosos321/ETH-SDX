/**
 * Global constants used throughout the Kentico / ArifPay integration.
 */
//SFESWCSD-92
public class ApiConstants {

    private ApiConstants() {}

    public static final String DONATION_TYPE_SPONSORSHIP = 'Sponsorship';
    // ---------------------------------------------------------------------
    // Donor Types
    // ---------------------------------------------------------------------
    public static final String DONOR_INDIVIDUAL = 'Individual';
    public static final String DONOR_CORPORATE  = 'Corporate';

    // ---------------------------------------------------------------------
    // Donation Types
    // ---------------------------------------------------------------------
    public static final String DONATION_ONE_OFF     = 'OneOff';
    public static final String DONATION_RECURRING   = 'Recurring Donation';
    public static final String DONATION_SPONSORSHIP = 'Sponsorship';

    // ---------------------------------------------------------------------
    // Sponsorship Types
    // ---------------------------------------------------------------------
    public static final String SPONSOR_CHILD        = 'Child';
    public static final String SPONSOR_FAMILY       = 'Family';
    public static final String SPONSOR_PROGRAM      = 'Program';
    public static final String SPONSOR_FOSTER_CARE  = 'FosterCare';

    // ---------------------------------------------------------------------
    // Installment Periods
    // ---------------------------------------------------------------------
    public static final String PERIOD_MONTHLY   = 'Monthly';
    public static final String PERIOD_QUARTERLY = 'Quarterly';
    public static final String PERIOD_YEARLY    = 'Yearly';

    // ---------------------------------------------------------------------
    // Payment Methods
    // ---------------------------------------------------------------------
    public static final String PAYMENT_CARD          = 'Credit Card';
    public static final String PAYMENT_BANK_TRANSFER = 'Bank Transfer';
    public static final String PAYMENT_MOBILE        = 'Mobile Money';

    // ---------------------------------------------------------------------
    // Payment Types
    // ---------------------------------------------------------------------
    public static final String PAYMENT_ONE_TIME = 'One Time';
    public static final String PAYMENT_RECURRING = 'Recurring';

    // Frequency
    // ---------------------------------------------------------------------
    public static final String FREQUENCY_MONTHLY = 'Monthly';
    public static final String FREQUENCY_ONE_OFF = 'One Off';

    // ---------------------------------------------------------------------
    // Payment Statuses
    // ---------------------------------------------------------------------
    public static final String STATUS_PENDING = 'Pending';
    public static final String STATUS_SUCCESS = 'Success';
    public static final String STATUS_FAILED  = 'Failed';
    public static final String STATUS_CANCELLED = 'Cancelled';

    // ---------------------------------------------------------------------
    // Opportunity Stages
    // ---------------------------------------------------------------------
    public static final String STAGE_PLEDGED    = 'Pledged';
    public static final String STAGE_CLOSED_WON = 'Closed Won';
    public static final String STAGE_CLOSED_LOST = 'Closed Lost';

    // ---------------------------------------------------------------------
    // Error Codes
    // ---------------------------------------------------------------------
    public static final String ERR_VALIDATION = 'VALIDATION_ERROR';
    public static final String ERR_DUPLICATE  = 'DUPLICATE_RECORD';
    public static final String ERR_PAYMENT    = 'PAYMENT_ERROR';
    public static final String ERR_SYSTEM     = 'SYSTEM_ERROR';

    // ---------------------------------------------------------------------
    // Sources
    // ---------------------------------------------------------------------
    public static final String SOURCE_KENTICO = 'Kentico';
    public static final String SOURCE_ARIFPAY = 'ArifPay';

    // ---------------------------------------------------------------------
    // REST Response Messages
    // ---------------------------------------------------------------------
    public static final String MSG_CREATED = 'Record created successfully.';
    public static final String MSG_UPDATED = 'Record updated successfully.';
    public static final String MSG_PAYMENT_RECEIVED = 'Payment processed successfully.';
    public static final String MSG_CANCELLED = 'Recurring donation cancelled.';
}