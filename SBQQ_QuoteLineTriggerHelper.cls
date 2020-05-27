/***
* Inserted New populateFieldsOnQuoteLine Method
* Added the logic to Populate Hidden and Optional Field values to QuoteLines
* Deployed on 23rd May 2020
***/
public class SBQQ_QuoteLineTriggerHelper {
    
    //populate fields on Quote Line Insert
    public static void populateFieldsOnInsert (List<SBQQ__QuoteLine__c> qliList) {
        for(SBQQ__QuoteLine__c qli : qliList) {
            qli.Product_Code__c = qli.SBQQ__PackageProductCode__c;
        }
    }
    
    //populate Asset details on Quote Line based on SBQQ__SubscribedAssetIds__c field
    public static void populateAssetDetails (List<SBQQ__QuoteLine__c> qliList) {
        Map<Id, Asset> assetIdMap = new Map<Id, Asset>();
        Set<String> assetIdSet = new Set<String>();

        for(SBQQ__QuoteLine__c qli : qliList){
            if(String.isNotBlank(qli.SBQQ__SubscribedAssetIds__c)) {
                for(String asstId : qli.SBQQ__SubscribedAssetIds__c.split(',')) {
                    asstId = asstId.trim();
                    assetIdSet.add(asstId); 
                }
            }
        }
        System.debug('Inside SBQQ_QuoteLineTriggerHelper.populateAssetDetails : assetIdSet :: '+assetIdSet);
        
        for(Asset ast : [SELECT Id, Name FROM Asset WHERE Id IN :assetIdSet]) {
            assetIdMap.put(ast.Id, ast);
        }
        System.debug('Inside SBQQ_QuoteLineTriggerHelper.populateAssetDetails : assetIdMap :: '+assetIdMap);
        
        for(SBQQ__QuoteLine__c qli : qliList) {
            String nameStr = '';
            if(String.isNotBlank(qli.SBQQ__SubscribedAssetIds__c) ) {
                for(String assetId : qli.SBQQ__SubscribedAssetIds__c.split(',')) {
                    assetId = assetId.trim();
                   
                    nameStr += assetIdMap.get( (Id) assetId ).Name+',';
                    
                    if( String.isBlank(qli.SubscribedAssetLookup__c) ) {
                        qli.SubscribedAssetLookup__c = (Id) assetId;
                    }
                }
                qli.SubscribedAssetNames__c = nameStr.removeEnd(',');
            }
        }
    }
    
    //SAL-148 : Method to throw error when Term on Subscription SKU is more than term on Premium Support sku on each bundle
    public static void populateBundlePremiumSupportAndSubscriptionTerm (List<SBQQ__QuoteLine__c> qliList) {
        
        Map<Id, Decimal> productBundleSubscriptTermMap = new Map<Id, Decimal> ();
        Map<Id, Decimal> productBundlePremiumSupportTermMap = new Map<Id, Decimal> ();
        List<SBQQ__QuoteLine__c> parentProductList = new List<SBQQ__QuoteLine__c> ();
        Set<Id> parentProductIdSet = new Set<Id> ();
        
        try {
            for (SBQQ__QuoteLine__c qli : qliList) {
                if (qli.SBQQ__RequiredBy__c != null && qli.SBQQ__SubscriptionTerm__c != null) {
                    if (qli.Is_Premium_Support__c) {
                        if (productBundlePremiumSupportTermMap.containsKey(qli.SBQQ__RequiredBy__c) 
                            && productBundlePremiumSupportTermMap.get(qli.SBQQ__RequiredBy__c) < qli.SBQQ__SubscriptionTerm__c) {
                                
                            productBundlePremiumSupportTermMap.put(qli.SBQQ__RequiredBy__c, qli.SBQQ__SubscriptionTerm__c);
                        } else if (!productBundlePremiumSupportTermMap.containsKey(qli.SBQQ__RequiredBy__c)) {
                            productBundlePremiumSupportTermMap.put(qli.SBQQ__RequiredBy__c, qli.SBQQ__SubscriptionTerm__c);
                        }
                        parentProductIdSet.add(qli.SBQQ__RequiredBy__c);
                    }   
                    if (!qli.Is_Premium_Support__c) {
                        if (productBundleSubscriptTermMap.containsKey(qli.SBQQ__RequiredBy__c) 
                            && productBundleSubscriptTermMap.get(qli.SBQQ__RequiredBy__c) < qli.SBQQ__SubscriptionTerm__c) {
                                
                            productBundleSubscriptTermMap.put(qli.SBQQ__RequiredBy__c, qli.SBQQ__SubscriptionTerm__c);
                        } else if (!productBundleSubscriptTermMap.containsKey(qli.SBQQ__RequiredBy__c)) {
                            productBundleSubscriptTermMap.put(qli.SBQQ__RequiredBy__c, qli.SBQQ__SubscriptionTerm__c);
                        }
                    }
                }
            }
            system.debug('qliList :: '+qliList);
            system.debug('parentProductIdSet :: '+parentProductIdSet);

            if(parentProductIdSet.size() > 0) {
                for (SBQQ__QuoteLine__c qli : [SELECT Id, Max_Subscription_Term__c, Bundle_Premium_Support_Term__c 
                                               FROM SBQQ__QuoteLine__c 
                                               WHERE Id IN :parentProductIdSet]) {
                                                   
                    qli.Max_Subscription_Term__c = productBundleSubscriptTermMap.get(qli.id);
                    qli.Bundle_Premium_Support_Term__c = productBundlePremiumSupportTermMap.get(qli.id);
                    parentProductList.add(qli);
                }
            }
            
            if (!parentProductList.isEmpty()) {
                  //update parentProductList;     
            }
            
        } catch (Exception e) {
            if(e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION')) {
                qliList[0].addError(e.getMessage().subStringAfter('FIELD_CUSTOM_VALIDATION_EXCEPTION,').removeEnd(': []'));
            } else {
                qliList[0].addError(e.getMessage());
            }
        } 
    }
	 public static void populateFieldsOnQuoteLine(Map<Id,SBQQ__QuoteLine__c> newQuoteLines){            
        if(newQuoteLines!=null && newQuoteLines.size()>0){
         if(System.IsBatch() == false && System.isFuture() == false){
           updateQuoteLines(newQuoteLines.keySet());
          }         
        }    
    }
    
    @future
    public static void updateQuoteLines(Set<Id> quoteLineIds){
          List<SBQQ__QuoteLine__c> quotelinesToUpdate = new List<SBQQ__QuoteLine__c>();
          List<SBQQ__QuoteLine__c> quoteLines = [select Id, SBQQ__Hidden__c, SBQQ__Optional__c from SBQQ__QuoteLine__c where Id IN:quoteLineIds and SBQQ__Product__r.Legacy_Software_Bundle__c = true and SBQQ__Quote__r.SBQQ__Type__c = 'Renewal'];
          system.debug('quotelines===' + quoteLines);
          if(quoteLines!=null && quoteLines.size()>0){
               for(SBQQ__QuoteLine__c quoteLine:quoteLines){
                     if(quoteLine.SBQQ__Hidden__c == false || quoteLine.SBQQ__Optional__c == false){
                        quoteLine.SBQQ__Hidden__c = true;
                        quoteLine.SBQQ__Optional__c = true; 
                        quotelinesToUpdate.add(quoteLine);
                      }
               } 
           }
           system.debug('quotelinesToUpdate===' + quotelinesToUpdate);
           if(quoteLinesToUpdate!=null && quotelinesToUpdate.size()>0){
               Database.update(quoteLinesToUpdate);
           }
    }

}