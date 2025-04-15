public class EcommerceServiceFactory {
    
    private static Map<String, Object> serviceCache = new Map<String, Object>();

   
    public static Object getService(String serviceTypeName) {
        if (String.isBlank(serviceTypeName)) {
            throw new EcommerceException('Service Type Name cannot be blank.');
        }
        
        return getServiceInstance(serviceTypeName);
    }

   
    private static Object getServiceInstance(String serviceTypeName) {
        
     
        String activeProvider = System.Label.Integration_Mode;

       
        if (String.isBlank(activeProvider) || activeProvider == 'Integration_Mode') {
             System.debug('ERROR: Active Ecommerce Provider not set correctly in Custom Label \'Integration_Mode\'. Please check the label exists and has a value.');
             throw new EcommerceException('Active Ecommerce Provider not configured correctly in Custom Label \'Integration_Mode\'.');
        }

        System.debug('Active Provider from Custom Label: \'' + activeProvider + '\', Requesting Service Type: \'' + serviceTypeName + '\'');

       
        String cacheKey = activeProvider + ':' + serviceTypeName;
        if (serviceCache.containsKey(cacheKey)) {
            System.debug('Returning cached service instance for key: ' + cacheKey);
            return serviceCache.get(cacheKey);
        }

        System.debug('Cache miss. Looking for service config for Provider: ' + activeProvider + ', Service: ' + serviceTypeName);

        // 3. Query Configuration (using the provider from the label, getting class and interface names)
        List<conectiontype__c> configs = [
            SELECT class_name__c, interface_name__c // <-- Query both fields
            FROM conectiontype__c
            WHERE provider__c = :activeProvider
              AND service__c = :serviceTypeName
            LIMIT 1
        ];

        // 4. Validate Configuration Result
        if (configs.isEmpty()) {
            System.debug('ERROR: No configuration found in conectiontype__c for Provider: ' + activeProvider + ', Service: ' + serviceTypeName);
            throw new EcommerceException('Ecommerce service configuration not found for Provider: ' + activeProvider + ', Service: ' + serviceTypeName);
        }

        conectiontype__c config = configs[0];
        String className = config.class_name__c;
        String interfaceName = config.interface_name__c; // <-- Get interface name from config

        if (String.isBlank(className)) {
             System.debug('ERROR: Configuration found, but class_name__c is blank for Provider: ' + activeProvider + ', Service: ' + serviceTypeName);
             throw new EcommerceException('Configuration error: class_name__c is blank for ' + activeProvider + '/' + serviceTypeName);
        }
        if (String.isBlank(interfaceName)) {
             System.debug('ERROR: Configuration found, but interface_name__c is blank for Provider: ' + activeProvider + ', Service: ' + serviceTypeName);
             throw new EcommerceException('Configuration error: interface_name__c is blank for ' + activeProvider + '/' + serviceTypeName);
        }

        System.debug('Found config: Class Name = ' + className + ', Interface Name = ' + interfaceName);

        Object instance = null;

        // 5. Instantiate the Class and Validate Interface Implementation
        try {
            Type classType = Type.forName(className);
            Type interfaceType = Type.forName(interfaceName); // <-- Get interface Type from config

            if (classType == null) {
                 System.debug('ERROR: Could not find Type for class name: ' + className);
                 throw new EcommerceException('Configuration error: Class ' + className + ' not found.');
            }
            if (interfaceType == null) {
                 System.debug('ERROR: Could not find Type for interface name: ' + interfaceName);
                 throw new EcommerceException('Configuration error: Interface ' + interfaceName + ' not found.');
            }

            instance = classType.newInstance();

            // Verify the instance's class implements or extends the expected interface/base class
            // Using isAssignableFrom is robust as it checks the type hierarchy.
            if (instance != null && interfaceType.isAssignableFrom(classType)) {
                System.debug('Successfully instantiated and verified class ' + className + ' implements/extends ' + interfaceName);
                serviceCache.put(cacheKey, instance); // Add to cache
                return instance;
            } else {
                 // This case should be rare if newInstance() succeeded and types were found,
                 // but good practice to check. Could happen with incorrect config.
                 System.debug('ERROR: Instantiated class ' + className + ' does not implement the expected interface ' + interfaceName);
                 throw new EcommerceException('Configuration error: Class ' + className + ' does not implement ' + interfaceName);
            }
        } catch (System.TypeException te) {
            // Catch specific TypeException for Type.forName() or casting issues
            System.debug('ERROR: Type error during service instantiation. Class: ' + className + ', Interface: ' + interfaceName + '. Message: ' + te.getMessage());
            throw new EcommerceException('Configuration error: Could not find Class \'' + className + '\' or Interface \'' + interfaceName + '\'. Check names and deployment.', te);
        } catch (Exception e) {
            // Catch other potential errors like newInstance() failure (e.g., no default constructor)
            System.debug('ERROR: Error instantiating class ' + className + '. Message: ' + e.getMessage() + '\nStackTrace: ' + e.getStackTraceString());
            throw new EcommerceException('Error creating service instance for ' + className + ': ' + e.getMessage(), e);
        }
    }

    // Custom Exception class for better error handling
    public class EcommerceException extends Exception {}

    // --- Interfaces (keep these defined outside the factory or in separate files) ---
    // public interface ICustomerService { ... }
    // public interface IOrderService { ... }

    // --- Implementation Classes (keep these defined outside the factory or in separate files) ---
    // public class MuleSoftCustomerService implements ICustomerService { ... }
    // public class SalesforceCustomerService implements ICustomerService { ... }
    // etc.
}