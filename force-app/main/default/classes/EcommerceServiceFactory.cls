 public with sharing  class EcommerceServiceFactory {  
    private static Map<String, Object> serviceCache = new Map<String, Object>();

    public static Object getService(String serviceTypeName) {
        if (String.isBlank(serviceTypeName)) {
            throw new EcommerceException('Service Type Name cannot be blank.');
        }
        
        return getServiceInstance(serviceTypeName);
    }

    private static Object getServiceInstance(String serviceTypeName) {
       
        conectiontype__c settings = conectiontype__c.getOrgDefaults();
        
        String activeProvider = settings?.provider__c; 
       
        if (String.isBlank(activeProvider)) {
             System.debug('ERROR: provider__c field not set in conectiontype__c Custom Setting. Please check the Org Defaults.');
            
             throw new EcommerceException('Active Ecommerce Provider not configured in the provider__c field of the conectiontype__c Custom Setting.');
        }

        System.debug('Active Provider from Custom Setting (conectiontype__c.provider__c): \'' + activeProvider + '\', Requesting Service Type: \'' + serviceTypeName + '\'');

        
        String cacheKey = activeProvider + ':' + serviceTypeName;
        if (serviceCache.containsKey(cacheKey)) {
            System.debug('Returning cached service instance for key: ' + cacheKey);
            return serviceCache.get(cacheKey);
        }

        System.debug('Cache miss. Looking for service config in service_provider_config__mdt for Provider: ' + activeProvider + ', Service: ' + serviceTypeName);

        // 3. Query Configuration from Custom Metadata Type 'service_provider_config__mdt'
        List<service_provider_config__mdt> configs = [
            SELECT class_name__c, interface_name__c
            FROM service_provider_config__mdt // Query the Custom Metadata Type
            WHERE provider__c = :activeProvider
              AND service__c = :serviceTypeName
            LIMIT 1
        ];

        if (configs.isEmpty()) {
            System.debug('ERROR: No configuration found in service_provider_config__mdt for Provider: ' + activeProvider + ', Service: ' + serviceTypeName);
            throw new EcommerceException('Ecommerce service configuration not found in service_provider_config__mdt for Provider: ' + activeProvider + ', Service: ' + serviceTypeName);
        }

       
        service_provider_config__mdt config = configs[0];
        String className = config.class_name__c;
        String interfaceName = config.interface_name__c; 

        
        if (String.isBlank(className)) {
             System.debug('ERROR: Configuration found in MDT, but class_name__c is blank for Provider: ' + activeProvider + ', Service: ' + serviceTypeName);
             throw new EcommerceException('Configuration error in service_provider_config__mdt: class_name__c is blank for ' + activeProvider + '/' + serviceTypeName);
        }
        if (String.isBlank(interfaceName)) {
             System.debug('ERROR: Configuration found in MDT, but interface_name__c is blank for Provider: ' + activeProvider + ', Service: ' + serviceTypeName);
             throw new EcommerceException('Configuration error in service_provider_config__mdt: interface_name__c is blank for ' + activeProvider + '/' + serviceTypeName);
        }

        System.debug('Found config in MDT: Class Name = ' + className + ', Interface Name = ' + interfaceName);

        Object instance = null;

        // 5. Instantiate the Class and Validate Interface Implementation 
        try {
            Type classType = Type.forName(className);
            Type interfaceType = Type.forName(interfaceName); 

            if (classType == null) {
                 System.debug('ERROR: Could not find Type for class name from MDT: ' + className);
                 throw new EcommerceException('Configuration error: Class ' + className + ' (from MDT) not found.');
            }
            if (interfaceType == null) {
                 System.debug('ERROR: Could not find Type for interface name from MDT: ' + interfaceName);
                 throw new EcommerceException('Configuration error: Interface ' + interfaceName + ' (from MDT) not found.');
            }

            instance = classType.newInstance();

            // Verify the instance's class implements or extends the expected interface/base class
            if (instance != null && interfaceType.isAssignableFrom(classType)) {
                System.debug('Successfully instantiated and verified class ' + className + ' implements/extends ' + interfaceName);
                serviceCache.put(cacheKey, instance); // Add to cache
                return instance;
            } else {
                 System.debug('ERROR: Instantiated class ' + className + ' does not implement the expected interface ' + interfaceName + ' (as defined in MDT)');
                 // Check if the class ExternContacService implements EcommerceInterface if this error occurs
                 throw new EcommerceException('Configuration error: Class ' + className + ' does not implement ' + interfaceName);
            }
        } catch (System.TypeException te) {
            System.debug('ERROR: Type error during service instantiation (MDT config). Class: ' + className + ', Interface: ' + interfaceName + '. Message: ' + te.getMessage());
            throw new EcommerceException('Configuration error: Could not find Class \'' + className + '\' or Interface \'' + interfaceName + '\' (defined in MDT). Check names and deployment.', te);
        } catch (Exception e) {
            System.debug('ERROR: Error instantiating class ' + className + ' (from MDT config). Message: ' + e.getMessage() + '\nStackTrace: ' + e.getStackTraceString());
            throw new EcommerceException('Error creating service instance for ' + className + ' (from MDT config): ' + e.getMessage(), e);
        }
    }

    // Custom Exception class remains the same
    public class EcommerceException extends Exception {}

   

   
}