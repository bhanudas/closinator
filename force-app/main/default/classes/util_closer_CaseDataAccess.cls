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
        return Database.getQueryLocator([
            SELECT Id, Status, LastModifiedDate, CreatedDate
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
}

