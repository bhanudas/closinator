/**
 * @description Data access layer for Case queries without sharing restrictions.
 * This class allows the batch system to query all Case records regardless of sharing rules,
 * enabling processing of Cases that the running user might not normally have access to.
 * 
 * Note: Updates still respect field-level security as they are performed in classes with sharing.
 */
public without sharing class util_closer_CaseDataAccess {
    
    /**
     * @description Queries Cases matching the specified criteria without sharing restrictions.
     * @param sourceStatuses Set of source status values to filter by.
     * @return Database.QueryLocator for Cases matching the criteria.
     */
    public static Database.QueryLocator queryCasesByStatus(Set<String> sourceStatuses) {
        if (sourceStatuses == null || sourceStatuses.isEmpty()) {
            util_closer_Logger.debug('CaseDataAccess', 'No source statuses provided. Returning empty query.');
            return Database.getQueryLocator('SELECT Id FROM Case WHERE Id = null');
        }
        
        util_closer_Logger.debug('CaseDataAccess', 'Querying Cases without sharing restrictions. Statuses: ' + sourceStatuses);
        
        // Use SOQL with bind variables for proper query execution
        // Note: RecordTypeId is available but we query it separately if needed for rule evaluation
        // Include Origin, Owner.Name, and LastModifiedBy.Name for rule filtering
        return Database.getQueryLocator([
            SELECT Id, Status, LastModifiedDate, CreatedDate, Origin,
                   Owner.Name, LastModifiedBy.Name
            FROM Case
            WHERE IsClosed = false
            AND Status IN :sourceStatuses
        ]);
    }
    
    /**
     * @description Queries Cases matching the specified criteria without sharing restrictions.
     * Includes additional fields that may be needed for rule evaluation.
     * Note: This method uses dynamic SOQL for additional fields. Use with caution.
     * @param sourceStatuses Set of source status values to filter by.
     * @param additionalFields Set of additional field API names to include in the query.
     * @return Database.QueryLocator for Cases matching the criteria.
     */
    public static Database.QueryLocator queryCasesByStatus(Set<String> sourceStatuses, Set<String> additionalFields) {
        if (sourceStatuses == null || sourceStatuses.isEmpty()) {
            util_closer_Logger.debug('CaseDataAccess', 'No source statuses provided. Returning empty query.');
            return Database.getQueryLocator('SELECT Id FROM Case WHERE Id = null');
        }
        
        Set<String> fields = new Set<String>{
            'Id', 'Status', 'LastModifiedDate', 'CreatedDate'
        };
        
        if (additionalFields != null && !additionalFields.isEmpty()) {
            fields.addAll(additionalFields);
        }
        
        String fieldList = String.join(new List<String>(fields), ', ');
        String query = 'SELECT ' + fieldList + ' ' +
                       'FROM Case ' +
                       'WHERE IsClosed = false ' +
                       'AND Status IN :sourceStatuses';
        
        util_closer_Logger.debug('CaseDataAccess', 'Querying Cases without sharing restrictions with additional fields. Statuses: ' + sourceStatuses);
        
        // Use Database.query for dynamic field lists with bind variables
        return Database.getQueryLocator(query);
    }
    
    /**
     * @description Queries Cases using a custom WHERE clause without sharing restrictions.
     * Use with caution - ensure the WHERE clause is properly formatted and secure.
     * @param whereClause SOQL WHERE clause (without the WHERE keyword).
     * @param additionalFields Set of field API names to include in the query.
     * @return Database.QueryLocator for Cases matching the criteria.
     */
    public static Database.QueryLocator queryCasesWithCustomWhere(String whereClause, Set<String> additionalFields) {
        if (String.isBlank(whereClause)) {
            util_closer_Logger.debug('CaseDataAccess', 'No WHERE clause provided. Returning empty query.');
            return Database.getQueryLocator('SELECT Id FROM Case WHERE Id = null');
        }
        
        Set<String> fields = new Set<String>{
            'Id', 'Status', 'LastModifiedDate', 'CreatedDate'
        };
        
        if (additionalFields != null && !additionalFields.isEmpty()) {
            fields.addAll(additionalFields);
        }
        
        String fieldList = String.join(new List<String>(fields), ', ');
        String query = 'SELECT ' + fieldList + ' ' +
                       'FROM Case ' +
                       'WHERE ' + whereClause;
        
        util_closer_Logger.debug('CaseDataAccess', 'Querying Cases without sharing restrictions with custom WHERE clause.');

        return Database.getQueryLocator(query);
    }

    /**
     * @description Queries child records related to Cases without sharing restrictions.
     * Uses dynamic SOQL to query any child object that has a lookup to Case.
     * @param childObjectApiName API name of the child object (e.g., 'UJET__UJET_Session__c').
     * @param childLookupField API name of the lookup field on child pointing to Case (e.g., 'UJET__Case__c').
     * @param childFilterField Optional field to include in query for filtering (e.g., 'UJET__Status__c').
     * @param caseIds Set of Case IDs to query children for.
     * @return List of child SObjects related to the specified Cases.
     */
    public static List<SObject> queryChildRecords(
        String childObjectApiName,
        String childLookupField,
        String childFilterField,
        Set<Id> caseIds
    ) {
        if (String.isBlank(childObjectApiName) || String.isBlank(childLookupField)) {
            util_closer_Logger.debug('CaseDataAccess', 'Missing child object or lookup field. Returning empty list.');
            return new List<SObject>();
        }

        if (caseIds == null || caseIds.isEmpty()) {
            util_closer_Logger.debug('CaseDataAccess', 'No Case IDs provided. Returning empty list.');
            return new List<SObject>();
        }

        // Validate that the object exists
        Schema.SObjectType childObjectType = Schema.getGlobalDescribe().get(childObjectApiName);
        if (childObjectType == null) {
            util_closer_Logger.error('CaseDataAccess: Child object ' + childObjectApiName + ' does not exist.');
            return new List<SObject>();
        }

        // Build the field list
        Set<String> fields = new Set<String>{ 'Id', childLookupField };
        if (String.isNotBlank(childFilterField)) {
            fields.add(childFilterField);
        }

        // Validate fields exist on the object
        Map<String, Schema.SObjectField> fieldMap = childObjectType.getDescribe().fields.getMap();
        Set<String> validFields = new Set<String>();
        for (String field : fields) {
            if (fieldMap.containsKey(field.toLowerCase())) {
                validFields.add(field);
            } else {
                util_closer_Logger.debug('CaseDataAccess', 'Field ' + field + ' not found on ' + childObjectApiName + ', skipping.');
            }
        }

        // Ensure lookup field is included (it's required)
        if (!validFields.contains(childLookupField) && !fieldMap.containsKey(childLookupField.toLowerCase())) {
            util_closer_Logger.error('CaseDataAccess: Lookup field ' + childLookupField + ' not found on ' + childObjectApiName);
            return new List<SObject>();
        }

        String fieldList = String.join(new List<String>(validFields), ', ');
        String query = 'SELECT ' + fieldList + ' ' +
                       'FROM ' + String.escapeSingleQuotes(childObjectApiName) + ' ' +
                       'WHERE ' + String.escapeSingleQuotes(childLookupField) + ' IN :caseIds';

        util_closer_Logger.debug('CaseDataAccess', 'Querying child records: ' + childObjectApiName + ' for ' + caseIds.size() + ' Cases');

        try {
            return Database.query(query);
        } catch (Exception e) {
            util_closer_Logger.error('CaseDataAccess: Error querying child records: ' + e.getMessage());
            return new List<SObject>();
        }
    }
}

