// Use .apex files to store anonymous Apex.
// You can execute anonymous Apex in VS Code by selecting the
//     apex text and running the command:
//     SFDX: Execute Anonymous Apex with Currently Selected Text
// You can also execute the entire file by running the command:
//     SFDX: Execute Anonymous Apex with Editor Contents
// --- Example Usage (e.g., in Anonymous Apex or another class) ---


// try {
//     // Get Customer Service
//     // Note the cast to (ICustomerService)
//     ICustomerService custService = (ICustomerService) EcommerceServiceFactory.getService('Customer Service');

//     if (custService != null) {
//         // Now you can call methods defined in ICustomerService
//         // Account customer = custService.getCustomerByEmail('test@example.com');
//         System.debug('Successfully retrieved Customer Service instance.');
//         // ... use custService methods ...
//     }

//     // Get Order Service
//     // Note the cast to (IOrderService)
//     IOrderService ordService = (IOrderService) EcommerceServiceFactory.getService('Order Service');

//     if (ordService != null) {
//         // Now you can call methods defined in IOrderService
//         // Order order = ordService.getOrderById('some-order-id');
//         System.debug('Successfully retrieved Order Service instance.');
//         // ... use ordService methods ...
//     }

//     // Example of getting a non-existent or misconfigured service
//     // try {
//     //     Object unknownService = EcommerceServiceFactory.getService('Inventory Service');
//     // } catch (EcommerceServiceFactory.EcommerceException e) {
//     //     System.debug('Expected Error: ' + e.getMessage());
//     // }

// } catch (EcommerceServiceFactory.EcommerceException e) {
//     // Handle exceptions from the factory (config errors, instantiation errors)
//     System.debug('ERROR retrieving service from factory: ' + e.getMessage());
//     // Log the error, show a message to the user, etc.
// } catch (System.TypeException te) {
//     // Handle potential casting errors if the configuration is wrong
//     System.debug('ERROR casting service instance. Check configuration. Message: ' + te.getMessage());
// } catch (Exception ex) {
//     // Handle any other unexpected errors
//     System.debug('An unexpected error occurred: ' + ex.getMessage());
// }


string externalOrderId = 'new';
ExternAccountService e = new ExternAccountService();

e.syncAccountByAccountNumber(externalOrderId);