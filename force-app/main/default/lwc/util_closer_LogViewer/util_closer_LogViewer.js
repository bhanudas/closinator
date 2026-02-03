import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getBatchLogs from '@salesforce/apex/util_closer_LogViewerController.getBatchLogs';
import getCaseLogs from '@salesforce/apex/util_closer_LogViewerController.getCaseLogs';
import getCaseLogFilterOptions from '@salesforce/apex/util_closer_LogViewerController.getCaseLogFilterOptions';
import exportCaseLogsAsCsv from '@salesforce/apex/util_closer_LogViewerController.exportCaseLogsAsCsv';

const BATCH_PAGE_SIZE = 25;
const CASE_PAGE_SIZE = 100;

const BATCH_COLUMNS = [
    { 
        label: 'Name', 
        fieldName: 'Name', 
        type: 'text',
        sortable: true,
        cellAttributes: { class: { fieldName: 'statusClass' } }
    },
    { 
        label: 'Status', 
        fieldName: 'Status__c', 
        type: 'text',
        sortable: true,
        cellAttributes: { class: { fieldName: 'statusClass' } }
    },
    { 
        label: 'Mode', 
        fieldName: 'Execution_Mode__c', 
        type: 'text',
        sortable: true 
    },
    { 
        label: 'Start Time', 
        fieldName: 'Start_Time__c', 
        type: 'date',
        sortable: true,
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }
    },
    { 
        label: 'Duration', 
        fieldName: 'durationFormatted', 
        type: 'text',
        sortable: false
    },
    { 
        label: 'Processed', 
        fieldName: 'Total_Records_Processed__c', 
        type: 'number',
        sortable: true 
    },
    { 
        label: 'Matched', 
        fieldName: 'Total_Records_Matched__c', 
        type: 'number',
        sortable: true 
    },
    { 
        label: 'Updated', 
        fieldName: 'Total_Records_Updated__c', 
        type: 'number',
        sortable: true 
    },
    { 
        label: 'Failed', 
        fieldName: 'Total_Records_Failed__c', 
        type: 'number',
        sortable: true,
        cellAttributes: { class: { fieldName: 'failedClass' } }
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'View Case Logs', name: 'view_cases' },
                { label: 'View Details', name: 'view_details' }
            ]
        }
    }
];

const CASE_COLUMNS = [
    { 
        label: 'Case #', 
        fieldName: 'Case_Number__c', 
        type: 'text',
        sortable: true 
    },
    { 
        label: 'Original Status', 
        fieldName: 'Original_Status__c', 
        type: 'text',
        sortable: true 
    },
    { 
        label: 'Target Status', 
        fieldName: 'Target_Status__c', 
        type: 'text',
        sortable: true 
    },
    { 
        label: 'Result', 
        fieldName: 'Processing_Result__c', 
        type: 'text',
        sortable: true,
        cellAttributes: { class: { fieldName: 'resultClass' } }
    },
    { 
        label: 'Matched Rule', 
        fieldName: 'Matched_Rule_Label__c', 
        type: 'text',
        sortable: true 
    },
    { 
        label: 'Rules Evaluated', 
        fieldName: 'Rules_Evaluated_Count__c', 
        type: 'number',
        sortable: true 
    },
    { 
        label: 'Time (ms)', 
        fieldName: 'Processing_Time_Ms__c', 
        type: 'number',
        sortable: true,
        typeAttributes: { maximumFractionDigits: 2 }
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'View Details', name: 'view_details' },
                { label: 'Open Case', name: 'open_case' }
            ]
        }
    }
];

export default class Util_closer_LogViewer extends NavigationMixin(LightningElement) {
    // Batch log state
    @track batchLogs = [];
    @track totalBatchRecords = 0;
    @track batchPageNumber = 1;
    @track batchTotalPages = 1;
    @track isBatchLoading = false;
    @track batchStatusFilter = '';
    @track batchModeFilter = '';
    @track startDate = '';
    @track endDate = '';
    @track searchTerm = '';
    @track batchSortField = 'CreatedDate';
    @track batchSortDirection = 'desc';
    @track statusCounts = {};
    @track modeCounts = {};

    // Case log state
    @track caseLogs = [];
    @track totalCaseRecords = 0;
    @track casePageNumber = 1;
    @track caseTotalPages = 1;
    @track isCaseLoading = false;
    @track isLoadingMore = false;
    @track selectedBatchLogId = null;
    @track selectedBatchName = '';
    @track caseResultFilter = '';
    @track caseRuleFilter = '';
    @track caseSearchTerm = '';
    @track caseSortField = 'CreatedDate';
    @track caseSortDirection = 'desc';
    @track resultCounts = {};
    @track ruleCounts = {};
    @track caseFilterOptions = {};

    // Modal state
    @track showCaseDetailModal = false;
    @track selectedCaseLog = {};

    // Column definitions
    batchColumns = BATCH_COLUMNS;
    caseColumns = CASE_COLUMNS;

    // Computed properties
    get showCaseLogs() {
        return this.selectedBatchLogId != null;
    }

    get mainContainerClass() {
        return 'main-container';
    }

    get batchPanelClass() {
        return this.showCaseLogs 
            ? 'batch-panel-container with-cases' 
            : 'batch-panel-container';
    }

    get casePanelClass() {
        return 'case-panel-container';
    }

    get isBatchFirstPage() {
        return this.batchPageNumber <= 1;
    }

    get isBatchLastPage() {
        return this.batchPageNumber >= this.batchTotalPages;
    }

    get caseLogsDisplayed() {
        return this.caseLogs.length;
    }

    get showFilterCounts() {
        return Object.keys(this.statusCounts).length > 0;
    }

    get showResultCounts() {
        return Object.keys(this.resultCounts).length > 0;
    }

    get enableInfiniteLoading() {
        return this.casePageNumber < this.caseTotalPages && !this.isLoadingMore;
    }

    get statusOptions() {
        return [
            { label: 'All Statuses', value: '' },
            { label: 'Running', value: 'Running' },
            { label: 'Completed', value: 'Completed' },
            { label: 'Completed with Errors', value: 'Completed with Errors' },
            { label: 'Failed', value: 'Failed' }
        ];
    }

    get modeOptions() {
        return [
            { label: 'All Modes', value: '' },
            { label: 'Full', value: 'Full' },
            { label: 'Simulation', value: 'Simulation' }
        ];
    }

    get resultOptions() {
        return [
            { label: 'All Results', value: '' },
            { label: 'Matched', value: 'Matched' },
            { label: 'Not Matched', value: 'Not Matched' },
            { label: 'Updated', value: 'Updated' },
            { label: 'Simulated', value: 'Simulated' },
            { label: 'Failed', value: 'Failed' }
        ];
    }

    get ruleOptions() {
        const options = [{ label: 'All Rules', value: '' }];
        if (this.caseFilterOptions.matchedRules) {
            this.caseFilterOptions.matchedRules.forEach(rule => {
                options.push({ label: rule, value: rule });
            });
        }
        return options;
    }

    get statusCountBadges() {
        return Object.entries(this.statusCounts).map(([status, count]) => ({
            value: status,
            label: `${status}: ${count}`,
            class: this.batchStatusFilter === status 
                ? 'slds-m-left_xx-small slds-badge_inverse' 
                : 'slds-m-left_xx-small'
        }));
    }

    get modeCountBadges() {
        return Object.entries(this.modeCounts).map(([mode, count]) => ({
            value: mode,
            label: `${mode}: ${count}`,
            class: this.batchModeFilter === mode 
                ? 'slds-m-left_xx-small slds-badge_inverse' 
                : 'slds-m-left_xx-small'
        }));
    }

    get resultCountBadges() {
        return Object.entries(this.resultCounts).map(([result, count]) => ({
            value: result,
            label: `${result}: ${count}`,
            class: this.caseResultFilter === result 
                ? 'slds-m-left_xx-small slds-badge_inverse' 
                : 'slds-m-left_xx-small'
        }));
    }

    // Lifecycle hooks
    connectedCallback() {
        this.loadBatchLogs();
    }

    // Batch log methods
    async loadBatchLogs() {
        this.isBatchLoading = true;
        try {
            const filter = {
                status: this.batchStatusFilter || null,
                executionMode: this.batchModeFilter || null,
                startDate: this.startDate || null,
                endDate: this.endDate || null,
                searchTerm: this.searchTerm || null,
                sortField: this.batchSortField,
                sortDirection: this.batchSortDirection
            };

            const result = await getBatchLogs({
                filterJson: JSON.stringify(filter),
                pageNumber: this.batchPageNumber,
                pageSize: BATCH_PAGE_SIZE
            });

            this.batchLogs = this.processBatchLogs(result.records);
            this.totalBatchRecords = result.totalRecords;
            this.batchTotalPages = result.totalPages;
            this.statusCounts = result.statusCounts || {};
            this.modeCounts = result.modeCounts || {};
        } catch (error) {
            this.showError('Error loading batch logs', error);
        } finally {
            this.isBatchLoading = false;
        }
    }

    processBatchLogs(records) {
        return records.map(record => ({
            ...record,
            durationFormatted: this.formatDuration(record.Duration_Seconds__c),
            statusClass: this.getStatusClass(record.Status__c),
            failedClass: record.Total_Records_Failed__c > 0 ? 'slds-text-color_error' : ''
        }));
    }

    formatDuration(seconds) {
        if (!seconds) return '-';
        if (seconds < 60) return `${seconds}s`;
        if (seconds < 3600) return `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
        const hours = Math.floor(seconds / 3600);
        const mins = Math.floor((seconds % 3600) / 60);
        return `${hours}h ${mins}m`;
    }

    getStatusClass(status) {
        switch (status) {
            case 'Completed': return 'slds-text-color_success';
            case 'Failed': return 'slds-text-color_error';
            case 'Completed with Errors': return 'slds-text-color_weak';
            case 'Running': return 'slds-text-color_default';
            default: return '';
        }
    }

    // Case log methods
    async loadCaseLogs(reset = true) {
        if (!this.selectedBatchLogId) return;

        if (reset) {
            this.isCaseLoading = true;
            this.caseLogs = [];
            this.casePageNumber = 1;
        } else {
            this.isLoadingMore = true;
        }

        try {
            const filter = {
                batchLogId: this.selectedBatchLogId,
                processingResult: this.caseResultFilter || null,
                matchedRule: this.caseRuleFilter || null,
                searchTerm: this.caseSearchTerm || null,
                sortField: this.caseSortField,
                sortDirection: this.caseSortDirection
            };

            const result = await getCaseLogs({
                filterJson: JSON.stringify(filter),
                pageNumber: this.casePageNumber,
                pageSize: CASE_PAGE_SIZE
            });

            const processedRecords = this.processCaseLogs(result.records);
            
            if (reset) {
                this.caseLogs = processedRecords;
            } else {
                this.caseLogs = [...this.caseLogs, ...processedRecords];
            }

            this.totalCaseRecords = result.totalRecords;
            this.caseTotalPages = result.totalPages;
            this.resultCounts = result.resultCounts || {};
            this.ruleCounts = result.ruleCounts || {};
        } catch (error) {
            this.showError('Error loading case logs', error);
        } finally {
            this.isCaseLoading = false;
            this.isLoadingMore = false;
        }
    }

    processCaseLogs(records) {
        return records.map(record => ({
            ...record,
            resultClass: this.getResultClass(record.Processing_Result__c)
        }));
    }

    getResultClass(result) {
        switch (result) {
            case 'Updated': 
            case 'Matched': return 'slds-text-color_success';
            case 'Failed': return 'slds-text-color_error';
            case 'Simulated': return 'slds-text-color_weak';
            case 'Not Matched': return '';
            default: return '';
        }
    }

    async loadCaseFilterOptions() {
        try {
            this.caseFilterOptions = await getCaseLogFilterOptions({
                batchLogId: this.selectedBatchLogId
            });
        } catch (error) {
            console.error('Error loading filter options:', error);
        }
    }

    // Event handlers - Batch filters
    handleBatchStatusChange(event) {
        this.batchStatusFilter = event.detail.value;
        this.batchPageNumber = 1;
        this.loadBatchLogs();
    }

    handleBatchModeChange(event) {
        this.batchModeFilter = event.detail.value;
        this.batchPageNumber = 1;
        this.loadBatchLogs();
    }

    handleStartDateChange(event) {
        this.startDate = event.detail.value;
        this.batchPageNumber = 1;
        this.loadBatchLogs();
    }

    handleEndDateChange(event) {
        this.endDate = event.detail.value;
        this.batchPageNumber = 1;
        this.loadBatchLogs();
    }

    handleSearchChange(event) {
        // Debounce search
        clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(() => {
            this.searchTerm = event.target.value;
            this.batchPageNumber = 1;
            this.loadBatchLogs();
        }, 300);
    }

    handleClearFilters() {
        this.batchStatusFilter = '';
        this.batchModeFilter = '';
        this.startDate = '';
        this.endDate = '';
        this.searchTerm = '';
        this.batchPageNumber = 1;
        this.loadBatchLogs();
    }

    handleStatusBadgeClick(event) {
        const value = event.target.dataset.value;
        this.batchStatusFilter = this.batchStatusFilter === value ? '' : value;
        this.batchPageNumber = 1;
        this.loadBatchLogs();
    }

    handleModeBadgeClick(event) {
        const value = event.target.dataset.value;
        this.batchModeFilter = this.batchModeFilter === value ? '' : value;
        this.batchPageNumber = 1;
        this.loadBatchLogs();
    }

    // Event handlers - Batch pagination and sorting
    handleBatchSort(event) {
        this.batchSortField = event.detail.fieldName;
        this.batchSortDirection = event.detail.sortDirection;
        this.loadBatchLogs();
    }

    handleBatchPreviousPage() {
        if (this.batchPageNumber > 1) {
            this.batchPageNumber--;
            this.loadBatchLogs();
        }
    }

    handleBatchNextPage() {
        if (this.batchPageNumber < this.batchTotalPages) {
            this.batchPageNumber++;
            this.loadBatchLogs();
        }
    }

    handleBatchRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;

        switch (action.name) {
            case 'view_cases':
                this.selectedBatchLogId = row.Id;
                this.selectedBatchName = row.Name;
                this.caseResultFilter = '';
                this.caseRuleFilter = '';
                this.caseSearchTerm = '';
                this.loadCaseLogs();
                this.loadCaseFilterOptions();
                break;
            case 'view_details':
                this.navigateToBatchLog(row.Id);
                break;
        }
    }

    // Event handlers - Case filters
    handleCaseResultChange(event) {
        this.caseResultFilter = event.detail.value;
        this.loadCaseLogs();
    }

    handleCaseRuleChange(event) {
        this.caseRuleFilter = event.detail.value;
        this.loadCaseLogs();
    }

    handleCaseSearchChange(event) {
        clearTimeout(this.caseSearchTimeout);
        this.caseSearchTimeout = setTimeout(() => {
            this.caseSearchTerm = event.target.value;
            this.loadCaseLogs();
        }, 300);
    }

    handleClearCaseFilters() {
        this.caseResultFilter = '';
        this.caseRuleFilter = '';
        this.caseSearchTerm = '';
        this.loadCaseLogs();
    }

    handleResultBadgeClick(event) {
        const value = event.target.dataset.value;
        this.caseResultFilter = this.caseResultFilter === value ? '' : value;
        this.loadCaseLogs();
    }

    // Event handlers - Case sorting and infinite scroll
    handleCaseSort(event) {
        this.caseSortField = event.detail.fieldName;
        this.caseSortDirection = event.detail.sortDirection;
        this.loadCaseLogs();
    }

    handleLoadMoreCases() {
        // Check if we can load more
        if (this.isLoadingMore) {
            return;
        }
        
        if (this.casePageNumber >= this.caseTotalPages) {
            // No more pages to load
            return;
        }
        
        this.casePageNumber++;
        this.loadCaseLogs(false);
    }

    handleCaseRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;

        switch (action.name) {
            case 'view_details':
                this.selectedCaseLog = row;
                this.showCaseDetailModal = true;
                break;
            case 'open_case':
                if (row.Case__c) {
                    this.navigateToCase(row.Case__c);
                }
                break;
        }
    }

    // Panel and modal handlers
    handleCloseCasePanel() {
        this.selectedBatchLogId = null;
        this.selectedBatchName = '';
        this.caseLogs = [];
    }

    closeCaseDetailModal() {
        this.showCaseDetailModal = false;
        this.selectedCaseLog = {};
    }

    handleViewCase() {
        if (this.selectedCaseLog.Case__c) {
            this.navigateToCase(this.selectedCaseLog.Case__c);
            this.closeCaseDetailModal();
        }
    }

    // Export handler
    async handleExportCsv() {
        try {
            const filter = {
                processingResult: this.caseResultFilter || null,
                matchedRule: this.caseRuleFilter || null,
                searchTerm: this.caseSearchTerm || null
            };

            const csvData = await exportCaseLogsAsCsv({
                batchLogId: this.selectedBatchLogId,
                filterJson: JSON.stringify(filter)
            });

            // Download CSV
            const blob = new Blob([csvData], { type: 'text/csv' });
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `case_logs_${this.selectedBatchName}_${new Date().toISOString().slice(0,10)}.csv`;
            a.click();
            window.URL.revokeObjectURL(url);

            this.showToast('Success', 'CSV exported successfully', 'success');
        } catch (error) {
            this.showError('Error exporting CSV', error);
        }
    }

    // Navigation helpers
    navigateToBatchLog(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'util_closer_Batch_Log__c',
                actionName: 'view'
            }
        });
    }

    navigateToCase(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
    }

    // Utility methods
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    showError(title, error) {
        const message = error?.body?.message || error?.message || 'Unknown error';
        console.error(title, error);
        this.showToast(title, message, 'error');
    }
}
