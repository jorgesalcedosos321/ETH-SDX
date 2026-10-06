/**
 * Creates operational Tasks for internal Users and Task-enabled Queues.
 *
 * This is a sibling of DLE_NotificationService, not part of the donor-email pipeline: there is no
 * event key, email configuration, suppression, send logging, or scheduling. One Task is created per
 * distinct owner. Expected validation and DML failures are returned to the caller and do not throw.
 *
 * The full request uses taskType instead of directly referencing Task.Type because that optional
 * standard field is not exposed in every Salesforce org. Runtime describe keeps the unlocked
 * package portable across those orgs.
 *
 * A Task owned by a Queue also bell-notifies that queue's direct members through
 * DLE_TaskQueueNotifier. That is best effort: it cannot fail a create, and anything that goes
 * wrong is appended to errors with a notification: prefix without touching any of the counts.
 */
public with sharing class DLE_TaskService {
  private static final String DEFAULT_STATUS = 'In Progress';

  /** Allows the DML-capacity guard to be exercised without consuming 10,000 rows in a test. */
  @TestVisible
  private static Integer dmlRowsRemainingOverride;

  /** Caller-supplied values shared by every owner-specific Task. */
  public class Request {
    public Set<Id> ownerIds = new Set<Id>();
    public String subject;
    public Id whoId;
    public Id whatId;
    public Date dueDate;
    public String status;
    public String priority;
    public String taskType;
    public String taskSubtype;
    public String description;
  }

  /** Outcome of a create call. Counts and ids refer to owner-specific Task records. */
  public class TaskResult {
    public Boolean success = false;
    public Integer createdCount = 0;
    public Integer failedCount = 0;
    public Map<Id, Id> taskIdsByOwner = new Map<Id, Id>();
    public List<String> errors = new List<String>();
  }

  /**
   * Validates the request-wide fields without inserting Tasks. Null owner entries are deliberately
   * ignored here because createTasks skips them individually; at least one non-null owner is still
   * required. Scheduled-task callers use this method before persisting a future request.
   */
  public static List<String> validateRequest(Request req) {
    List<String> errors = new List<String>();
    if (req == null) {
      errors.add('request is required');
      return errors;
    }

    Boolean hasOwner = false;
    if (req.ownerIds != null) {
      for (Id ownerId : req.ownerIds) {
        if (ownerId != null) {
          hasOwner = true;
          break;
        }
      }
    }
    if (!hasOwner) {
      errors.add('at least one owner id is required');
    }
    if (String.isBlank(req.subject)) {
      errors.add('subject is required');
    } else if (req.subject.length() > 255) {
      errors.add('subject cannot exceed 255 characters');
    }
    errors.addAll(validatePicklists(picklistValues(req)));
    return errors;
  }

  /** Convenience: create one Task with Status = In Progress. */
  public static TaskResult createTask(Id ownerId, String subject) {
    Request req = new Request();
    req.ownerIds.add(ownerId);
    req.subject = subject;
    return createTasks(req);
  }

  /** Convenience: create one Task per distinct owner with Status = In Progress. */
  public static TaskResult createTasks(Set<Id> ownerIds, String subject) {
    Request req = new Request();
    if (ownerIds != null) {
      req.ownerIds.addAll(ownerIds);
    }
    req.subject = subject;
    return createTasks(req);
  }

  /**
   * Creates one Task per distinct owner. Individual DML failures do not roll back successful
   * owners. Request-wide validation failures (such as a bad picklist value) insert nothing.
   */
  public static TaskResult createTasks(Request req) {
    TaskResult result = new TaskResult();
    if (req == null) {
      result.errors.add('request is required');
      return result;
    }

    Set<Id> cleanedOwnerIds = new Set<Id>();
    if (req.ownerIds != null) {
      for (Id ownerId : req.ownerIds) {
        if (ownerId == null) {
          result.failedCount++;
          result.errors.add('skipped owner null: owner id is required');
        } else {
          cleanedOwnerIds.add(ownerId);
        }
      }
    }
    if (cleanedOwnerIds.isEmpty()) {
      if (result.errors.isEmpty()) {
        result.errors.add('at least one owner id is required');
      }
      return result;
    }

    List<String> validationErrors = validateRequest(req);
    if (!validationErrors.isEmpty()) {
      result.failedCount += cleanedOwnerIds.size();
      result.errors.addAll(validationErrors);
      return result;
    }
    Map<String, String> picklistValuesByField = picklistValues(req);

    Integer remainingDmlRows = dmlRowsRemainingOverride == null
      ? Limits.getLimitDmlRows() - Limits.getDmlRows()
      : dmlRowsRemainingOverride;
    if (cleanedOwnerIds.size() > remainingDmlRows) {
      result.failedCount += cleanedOwnerIds.size();
      result.errors.add(
        'cannot create ' +
          cleanedOwnerIds.size() +
          ' tasks: only ' +
          remainingDmlRows +
          ' DML rows remain in this transaction'
      );
      return result;
    }

    List<Id> ownersByTaskIndex = new List<Id>();
    List<Task> tasks = new List<Task>();
    for (Id ownerId : cleanedOwnerIds) {
      Task taskRecord = new Task(
        OwnerId = ownerId,
        Subject = req.subject,
        WhoId = req.whoId,
        WhatId = req.whatId,
        ActivityDate = req.dueDate,
        Description = req.description
      );
      for (String fieldApiName : picklistValuesByField.keySet()) {
        String value = picklistValuesByField.get(fieldApiName);
        if (value != null) {
          taskRecord.put(fieldApiName, value);
        }
      }
      ownersByTaskIndex.add(ownerId);
      tasks.add(taskRecord);
    }

    try {
      Database.SaveResult[] saveResults = Database.insert(tasks, false);
      for (Integer i = 0; i < saveResults.size(); i++) {
        Id ownerId = ownersByTaskIndex[i];
        Database.SaveResult saveResult = saveResults[i];
        if (saveResult.isSuccess()) {
          result.createdCount++;
          result.taskIdsByOwner.put(ownerId, saveResult.getId());
        } else {
          result.failedCount++;
          result.errors.add(describeErrors(ownerId, saveResult.getErrors()));
        }
      }
    } catch (DmlException ex) {
      // Database.insert(..., false) normally reports row errors as SaveResults. Preserve the
      // caller's transaction if Salesforce rejects the operation before returning results.
      result.failedCount += tasks.size();
      result.errors.add('task insert failed: ' + ex.getMessage());
    }

    // Queue owners only, and only for Tasks that really were created. Notification problems are
    // reported in errors but never counted: failedCount must keep meaning "Tasks not inserted",
    // because DLE_ScheduledTaskProcessor reads it to decide between Created and Partial.
    if (!result.taskIdsByOwner.isEmpty()) {
      try {
        for (
          String problem : DLE_TaskQueueNotifier.notifyQueueOwners(
            result.taskIdsByOwner,
            req.subject
          )
        ) {
          result.errors.add('notification: ' + problem);
        }
      } catch (Exception ex) {
        result.errors.add('notification: ' + ex.getMessage());
      }
    }

    result.success = result.createdCount > 0;
    return result;
  }

  private static String normalizeOptional(String value) {
    return String.isBlank(value) ? null : value.trim();
  }

  private static Map<String, String> picklistValues(Request req) {
    return new Map<String, String>{
      'Status' => String.isBlank(req.status)
        ? DEFAULT_STATUS
        : req.status.trim(),
      'Priority' => normalizeOptional(req.priority),
      'Type' => normalizeOptional(req.taskType),
      'TaskSubtype' => normalizeOptional(req.taskSubtype)
    };
  }

  private static List<String> validatePicklists(
    Map<String, String> valuesByField
  ) {
    List<String> errors = new List<String>();
    Map<String, Schema.SObjectField> taskFields = Schema.SObjectType.Task.fields.getMap();

    for (String fieldApiName : valuesByField.keySet()) {
      String value = valuesByField.get(fieldApiName);
      if (value == null) {
        continue;
      }

      Schema.SObjectField fieldToken = taskFields.get(fieldApiName);
      if (fieldToken == null || !fieldToken.getDescribe().isCreateable()) {
        errors.add(
          'Task.' +
            fieldApiName +
            ' is unavailable or not createable in this org'
        );
        continue;
      }

      Boolean isValid = false;
      List<String> activeValues = new List<String>();
      for (
        Schema.PicklistEntry entry : fieldToken.getDescribe()
          .getPicklistValues()
      ) {
        if (entry.isActive()) {
          activeValues.add(entry.getValue());
          if (entry.getValue() == value) {
            isValid = true;
          }
        }
      }
      if (!isValid) {
        errors.add(
          'invalid Task.' +
            fieldApiName +
            ' value: ' +
            value +
            '; active values: ' +
            String.join(activeValues, ', ')
        );
      }
    }
    return errors;
  }

  private static String describeErrors(Id ownerId, Database.Error[] errors) {
    List<String> parts = new List<String>();
    for (Database.Error error : errors) {
      parts.add(error.getStatusCode() + ': ' + error.getMessage());
    }
    return 'owner ' + ownerId + ': ' + String.join(parts, '; ');
  }
}