import fs from "node:fs/promises";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outputDir = "outputs/email-variable-conditions";
const outputPath = `${outputDir}/email_variable_conditions.xlsx`;

const rows = [
  ["ANNIVERSARY_EMAIL_1", "Recurring Donation is a sponsorship; Contact is populated; CreatedDate month/day equals the run date; CreatedDate is before the current year; and this record is the Contact's earliest sponsorship. Source: SendEmailNotificationBatch.cls lines 42-55, 441-497.", "Schedulable batch; no System.schedule call is active or documented for this key in the repository."],
  ["BIRTHDAY_EMAIL", "Contact Birthdate month/day equals the run date and Contact.Email is populated. Source: SendEmailNotificationBatch.cls lines 33-41.", "Schedulable batch; no System.schedule call is active or documented for this key in the repository."],
  ["CANCELLATION_PROCESS", "On Recurring Donation update: status changes to Closed or Lapsed; Donation Type is Sponsorship; Closed Reason is not blank; Contact is populated; and at least one related future Opportunity is Pledged with CloseDate after today. Source: RecurringDonationHandler.cls lines 44-50; RecurringDonationService.cls lines 851-926.", "No — trigger-driven after Recurring Donation update."],
  ["END_OF_YEAR_REPORT_P", "Contact.Email is populated and Contact has an Active sponsorship Recurring Donation. Source: SendEmailNotificationBatch.cls lines 57-68.", "Intended annual schedule: December 30 at 00:00; setup call is commented, so repository metadata does not prove an active org job."],
  ["LOYALTY_CALL_AFTER_6", "Recurring Donation has a Contact whose Email is populated; exactly six related Opportunities exist in Closed Won/Closed Lost/Declined/Missed; all six are Closed Won; installment numbers are non-null and consecutive. Creates a Task, not an email. Source: SendEmailNotificationBatch.cls lines 69-80, 146-151, 237-323.", "Schedulable batch; no System.schedule call is active or documented for this key in the repository."],
  ["MID_YEAR_REPORT_PDF", "Contact.Email is populated and Contact has an Active sponsorship Recurring Donation. Source: SendEmailNotificationBatch.cls lines 82-93.", "Intended annual schedule: June 1 at 00:00; setup call is commented, so repository metadata does not prove an active org job."],
  ["ONE_TIME_DONORS_LE", "Opportunity Donation Type is One-time Donation; CreatedDate falls on the one-month anniversary window for the run date; and Primary Contact or ContactId is populated (Primary Contact takes precedence). Short-month anniversaries are handled on the following month's last day. Source: SendEmailNotificationBatch.cls lines 94-114, 185-194, 207-235.", "Intended daily schedule at 00:00; setup call is commented, so repository metadata does not prove an active org job."],
  ["ONE_TIME_DONORS_TH", "On Opportunity insert: Donation Type is One-time Donation and Primary Contact or ContactId is populated (Primary Contact takes precedence). No Stage condition is applied. Source: OpportunityHandler.cls lines 22-28; OpportunityService.cls lines 225-255.", "No — trigger-driven after Opportunity insert."],
  ["PAYMENT_CONFIRMATION", "On Opportunity update: previous Stage is not Closed Won and new Stage is Closed Won; Opportunity is non-recurring, or it is recurring installment 1; and Primary Contact or ContactId is populated. Source: OpportunityHandler.cls lines 30-37; OpportunityService.cls lines 325-380.", "No — trigger-driven after Opportunity update."],
  ["REMINDER_1", "Recurring Donation has a Contact and related missed-stage Opportunity; its latest history contains exactly 1 consecutive miss, in the month immediately before the run month. Miss stages: Declined, Missed, Closed Lost. Source: SendEmailNotificationBatch.cls lines 115-127, 329-436.", "Intended daily schedule at 00:00; setup call is commented, so repository metadata does not prove an active org job."],
  ["REMINDER_2", "Recurring Donation has a Contact and related missed-stage Opportunity; its latest history contains exactly 2 consecutive misses, one in each of the two months before the run month. Miss stages: Declined, Missed, Closed Lost. Source: SendEmailNotificationBatch.cls lines 115-127, 329-436.", "Intended daily schedule at 00:00; setup call is commented, so repository metadata does not prove an active org job."],
  ["REMINDER_3", "Recurring Donation has a Contact and related missed-stage Opportunity; its latest history contains exactly 3 consecutive misses, one in each of the three months before the run month. Miss stages: Declined, Missed, Closed Lost. Source: SendEmailNotificationBatch.cls lines 115-127, 329-436.", "Intended daily schedule at 00:00; setup call is commented, so repository metadata does not prove an active org job."],
  ["THANK_YOU_EMAIL_AFTER_12", "On Recurring Donation update: Donation Type is Recurring Donation; Contact is populated; Total Paid Installments increases; and the new value is exactly integer 12. Source: RecurringDonationHandler.cls lines 44-49; RecurringDonationService.cls lines 682-748.", "No — trigger-driven after Recurring Donation update."],
  ["THANK_YOU_EMAIL_AFTER_2", "On Recurring Donation update: Donation Type is Recurring Donation; Contact is populated; Total Paid Installments increases; and the new value is exactly integer 2. Source: RecurringDonationHandler.cls lines 44-49; RecurringDonationService.cls lines 682-748.", "No — trigger-driven after Recurring Donation update."],
  ["THANK_YOU_EMAIL_AFTER_3", "On Recurring Donation update: Donation Type is Recurring Donation; Contact is populated; Total Paid Installments increases; and the new value is exactly integer 3. Source: RecurringDonationHandler.cls lines 44-49; RecurringDonationService.cls lines 682-748.", "No — trigger-driven after Recurring Donation update."],
  ["THANK_YOU_EMAIL_AFTER_4", "On Recurring Donation update: Donation Type is Recurring Donation; Contact is populated; Total Paid Installments increases; and the new value is exactly integer 4. Source: RecurringDonationHandler.cls lines 44-49; RecurringDonationService.cls lines 682-748.", "No — trigger-driven after Recurring Donation update."],
  ["THANK_YOU_EMAIL_AFTER_6", "On Recurring Donation update: Donation Type is Recurring Donation; Contact is populated; Total Paid Installments increases; and the new value is exactly integer 6. Source: RecurringDonationHandler.cls lines 44-49; RecurringDonationService.cls lines 682-748.", "No — trigger-driven after Recurring Donation update."],
  ["WELCOME_EMAIL_COMMUN", "On Recurring Donation insert: Donation Type is Sponsorship and Contact is populated. Source: RecurringDonationHandler.cls lines 35-42; RecurringDonationService.cls lines 364-400.", "No — trigger-driven after Recurring Donation insert."],
  ["WELCOME_THE_NEW_DONO", "On Recurring Donation insert: Donation Type is Recurring Donation; Contact is populated; and all such recurring donations currently stored for that Contact are part of the current insert transaction (there was no earlier committed recurring donation). Source: RecurringDonationHandler.cls lines 35-42; RecurringDonationService.cls lines 503-548, 646-678.", "No — trigger-driven after Recurring Donation insert."],
];

const workbook = Workbook.create();
const sheet = workbook.worksheets.add("Email conditions");
sheet.showGridLines = false;
sheet.getRange("A1:C1").merge();
sheet.getRange("A1").values = [["Utils email variables"]];
sheet.getRange("A2:C2").merge();
sheet.getRange("A2").values = [["Conditions and execution model traced across the Salesforce project"]];
sheet.getRange("A3:C3").merge();
sheet.getRange("A3").values = [["Common send prerequisites: the DLE global kill switch must be off, the dispatch config must exist and be active, the email template must resolve, and recipient policy must allow delivery. Scheduling statements found in SendEmailNotificationBatch.cls are comments; active org CronTrigger records are outside repository scope."]];
sheet.getRange("A5:C5").values = [["Variable name", "Conditions that must be met", "Scheduled?"]];
sheet.getRange(`A6:C${rows.length + 5}`).values = rows;

sheet.getRange("A1:C1").format = { font: { name: "Arial", size: 16, bold: true, color: "#1F2937" } };
sheet.getRange("A2:C2").format = { font: { name: "Arial", size: 10, italic: true, color: "#4B5563" } };
sheet.getRange("A3:C3").format = { fill: "#FFF7ED", font: { name: "Arial", size: 9, color: "#7C2D12" }, wrapText: true, verticalAlignment: "center" };
sheet.getRange("A5:C5").format = { fill: "#1F4E78", font: { name: "Arial", size: 10, bold: true, color: "#FFFFFF" }, horizontalAlignment: "center", verticalAlignment: "center", wrapText: true, borders: { preset: "inside", style: "thin", color: "#FFFFFF" } };
const body = sheet.getRange(`A6:C${rows.length + 5}`);
body.format = { font: { name: "Arial", size: 10, color: "#1F2937" }, verticalAlignment: "top", wrapText: true, borders: { insideHorizontal: { style: "thin", color: "#D1D5DB" } } };
sheet.getRange(`A6:A${rows.length + 5}`).format.font = { name: "Arial", size: 10, bold: true, color: "#1F4E78" };
sheet.getRange(`C6:C${rows.length + 5}`).conditionalFormats.addCustom('=LEFT($C6,2)="No"', { fill: "#F3F4F6", font: { color: "#374151" } });
sheet.getRange(`C6:C${rows.length + 5}`).conditionalFormats.addCustom('=LEFT($C6,8)="Intended"', { fill: "#FEF3C7", font: { color: "#92400E" } });
sheet.getRange(`C6:C${rows.length + 5}`).conditionalFormats.addCustom('=LEFT($C6,11)="Schedulable"', { fill: "#E0F2FE", font: { color: "#075985" } });
sheet.getRange("A1:C25").format.font.name = "Arial";
sheet.getRange("A:A").format.columnWidth = 31;
sheet.getRange("B:B").format.columnWidth = 88;
sheet.getRange("C:C").format.columnWidth = 55;
sheet.getRange("1:1").format.rowHeight = 25;
sheet.getRange("2:2").format.rowHeight = 20;
sheet.getRange("3:3").format.rowHeight = 55;
sheet.getRange("5:5").format.rowHeight = 30;
sheet.getRange(`6:${rows.length + 5}`).format.autofitRows();
sheet.freezePanes.freezeRows(5);
const table = sheet.tables.add(`A5:C${rows.length + 5}`, true, "EmailConditionsTable");
table.style = "TableStyleMedium2";
table.showBandedRows = true;

await fs.mkdir(outputDir, { recursive: true });
const preview = await workbook.render({ sheetName: "Email conditions", range: `A1:C${rows.length + 5}`, scale: 1, format: "png" });
await fs.writeFile(`${outputDir}/preview.png`, new Uint8Array(await preview.arrayBuffer()));
const check = await workbook.inspect({ kind: "table", range: `Email conditions!A1:C${rows.length + 5}`, include: "values,formulas", tableMaxRows: 30, tableMaxCols: 3 });
console.log(check.ndjson);
const errors = await workbook.inspect({ kind: "match", searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!", options: { useRegex: true, maxResults: 100 }, summary: "final formula error scan" });
console.log(errors.ndjson);
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);
console.log(outputPath);
