# Lunu Payment Widget. Ruby on Rails Version


Copy this files to the your app directory

Open file "app/controllers/lunu_pay_controller.rb" and edit the fields **CALLBACK_URL**, **APP_ID** and **API_SECRET**.


```ruby
APP_ID = '149ec6da-f0dc-4cdf-9fb3-8ba2dc602f60'
API_SECRET = '23d93cac-000f-5000-8000-126728f15140'

# Your callback url should be here
CALLBACK_URL = 'https://your-site.com/lunu_pay/notify'
```



## Lunu Payment API. General information.

API endpoint: https://{rc|alpha}.lunu.io/api/v1/

Server versions:

  * alpha - production server
  * rc - test server


The API is available for authorized users.
Unauthorized users receive an empty response and status
```
404 Not found
```

All responses are returned in JSON format.

The responses from the server are wrapped:

  * a successful response is returned in the response field:
```
{
   "response": {...}
}
```

  * if it is necessary to return an error, then the error is returned in the error field, for example:

```
{
   "error": {
     "code": 1,
     "message": "..."
   }
}
```

### Authentication

HTTP Basic Auth must be used to authenticate requests.
For the request headers, you must enter the merchant ID as the username, and the secret key as the password.

Example header:
```
Authorization: Basic QWxhZGRpbjpPcGVuU2VzYW1l
```
where QWxhZGRpbjpPcGVuU2VzYW1l is the result of the function: base64(app_id + ':' + secret_key)


### Idempotency

From the API's point of view, idempotency means that multiple requests are handled in the same way as single requests.  
It means that upon receiving a repeated request with the same parameters, the Processing Service will return the result of the original request in response.  
This approach helps to avoid the unwanted replay of transactions. For example, if during a payment there are network problems and the connection is interrupted, you can safely repeat the required request as many times as you need.  
GET requests are idempotent by default, since they have no unwanted consequences.  
To ensure the idempotency of POST requests, the Idempotence-Key header (or idempotence key) is used.

Example header:
```
Idempotence-Key: 3134353
```
where 3134353 is the result of the function: uniqid()



### Scenario for making a payment through the Widget

When the user proceeds to checkout (this can be either a single product or a basket of products),
the payment process goes through the following stages:



#### 1. Payment creation. payments/create

The merchant's website or application sends a request to the **Processing Service** to create a payment, which looks like this:
```
POST https://alpha.lunu.io/api/v1/payments/create
Authorization: Basic QWxhZGRpbjpPcGVuU2VzYW1l
Idempotence-Key: 3134353
Content-Type: application/json
```
```json
{
  "amount": 1.00,
  "callback_url": "https://website.com/api/change-status",
  "cancel_url": "https://website.com/cancel",
  "success_url": "https://website.com/success",
  "description": "Order #1",
  "expires": "2020-02-22T00:00:00-00:00",
  "test": false
}
```

Description of fields:

  * amount (number) - payment amount (currency is indicated in the merchant's profile);
  * callback_url (string) (optional parameter) - url-address of the store's callback API,
    to which the **Processing service** will send a request when the payment status changes (when the payment is made)

  * cancel_url (string) (optional parameter) - the page to which the service will
    transfer the user if the payment is canceled.
    This functionality is relevant if payment is made via a separate payment page;

  * success_url (string) (optional parameter) - the page to which the service will
    transfer the user if the payment is successful.
    This functionality is relevant if payment is made via a separate payment page;

  * description (string) (optional parameter) - if you need to add a description of the payment
    that the seller wants to see in its personal account, then you need to pass the description parameter.
    The description should be no more than 128 characters.

  * expires (string) (optional parameter) - date when the payment expires, in RFC3339 format. By default: 1 minute from the moment of sending;

  * test (boolean) (optional parameter) - a flag indicating that the API is being used in test mode.
    True if the payment is made in test mode. Default: false.
    This parameter ignored in the current version of our system.


The **Processing Service** returns the created payment object with a token for initializing the widget.
```json
{
  "id": "23d93cac-000f-5000-8000-126628f15141",
  "status": "pending",
  "test": false,
  "amount": 1.00,
  "currency": "EUR",
  "description": "Order #1",
  "confirmation_token": "ct-24301ae5-000f-5000-9000-13f5f1c2f8e0",
  "created_at": "2019-01-22T14:30:45-03:00",
  "expires": "2020-02-22T00:00:00-00:00"
}
```

Description of fields:

  * id (string) - payment ID;

  * status (string) - payment status. Value options:  

    * "pending" - awaiting payment;  
    * "paid" - payment has been made;  
    * "canceled" - the payment was canceled by the seller;  
    * "expired" - the time allotted for the payment has expired;  



  * amount (number)- amount of payment;

  * currency (string) - payment currency;

  * test (boolean) - a flag indicating that the API is being used in test mode.
    True if the payment is made in test mode.

  * description (string) - payment description, no more than 128 characters;

  * confirmation_token (string) - payment token, which is required to initialize the widget;

  * created_at (string) - the date the payment was created;

  * expires (string) - the date when the payment expires, in RFC3339 format.




#### 2. Initialize the widget and display the forms on the payment page.

To initialize the widget, insert the following code into the body of the html page:

```html
<!-- Library connection -->

<!-- production server -->
<script src="https://plugins.lunu.io/packages/widget-ui/alpha.js"></script>

<!-- test server -->
<!--
<script src="https://plugins.lunu.io/packages/widget-ui/rc.js"></script>
-->

<!-- HTML element in which the payment form will be displayed -->
<div id="payment-form"></div>

<script>
// Initialization of the widget.
const widget = new window.Lunu.widgets.Payment(
  document.getElementById('payment-form'), // Required parameter
  {
    /*
    Token that must be received from the Processing Service before making a payment
    Required parameter
    */
    confirmation_token: 'ct-24301ae5-000f-5000-9000-13f5f1c2f8e0',

    overlay: true, // show widget over page
    callbacks: {
      init_error(error) {
        // Handling initialization errors
      },
      init_success(data) {
        // Handling a Successful Initialization
      },
      payment_paid() {
        // Handling a successful payment event
      },
      payment_cancel() {
        // Handling a payment cancellation event
      },
      payment_close() {
        // Handling the event of closing the widget window
      },
    },
  },
);
</script>
```



#### 3. Notifying the seller's store about a change in payment status. Payment Callback

When the user has made a payment, the **Processing Service** sends a request in the
following format to the store's API url, which was specified at the time of creating the payment:

```
POST https://website.com/api/change-status
```
```json
{
  "id": "23d93cac-000f-5000-8000-126628f15141",
  "status": "paid",
  "test": false,
  "amount": 1.00,
  "currency": "EUR",
  "description": "Order #1",
  "created_at": "2019-01-22T14:30:45-03:00",
  "expires": "2020-02-22T00:00:00-00:00"
}
```

Description of fields:

  * id (string) - payment ID;

  * status (string) - payment status. Value options:

    * "paid" - payment has been made;  
    * "canceled" - the payment was canceled by the seller;  
    * "expired" - the time allotted for the payment has expired;  



  * amount (number)- amount of payment;

  * currency (string) - payment currency;

  * test (boolean) - a flag indicating that the API is being used in test mode.
    True if the payment is made in test mode.

  * description (string) - payment description, no more than 128 characters;

  * created_at (string) - the date the payment was created;

  * expires (string) - the date when the payment expires, in RFC3339 format.




#### 4. The store checks the validity of the notification received. payments/get/{payment_id}

After the merchant has received a notification about the change in the payment status,
he needs to check the validity of this notification through the **Processing Service**
by the following request:
```
POST https://alpha.lunu.io/api/v1/payments/get/{payment_id}
Authorization: Basic QWxhZGRpbjpPcGVuU2VzYW1l
```

If everything is good then the **Processing Service** returns an identical payment object:
```
{
  "id": "23d93cac-000f-5000-8000-126628f15141",
  "status": "paid",
  "test": false,
  "amount": 1.00,
  "currency": "EUR",
  "description": "Order #1",
  "created_at": "2019-01-22T14:30:45-03:00",
  "expires": "2020-02-22T00:00:00-00:00",
}
```



## Additional examples


### This code creates a payment and immediately opens a payment widget on some event

```html
<script src="https://plugins.lunu.io/packages/widget-ui/omega.js"></script>
<script>
const paymentAPI = new window.Lunu.API({
  endpoint: '/lunu_pay/create',  // Your API endpoint
});
function openWidget(orderId) {
  paymentAPI.create({
    /*
      All of this user data is sent to the your endpoint script where you should handle it.
    */
    order_id: orderId,
    authenticity_token: '<%= form_authenticity_token %>',
  }, {
    // version: 'rc', // test server
    version: 'alpha', // production server
  })
      .then(function(result) {
        var status = result.status;
        if (status === 'canceled') {
          // Handling a payment cancellation event
        }
        if (status === 'paid') {
          // Handling a successful payment event
        }
      });
}
</script>
<button
  onclick="openWidget('YOUR ORDER ID')"
>Proceed to pay</button>
```




### How do redirect on success payment?

```html
<script src="https://plugins.lunu.io/packages/widget-ui/omega.js"></script>
<script>
const paymentAPI = new window.Lunu.API({
  endpoint: '/lunu-pay/api.php',  // Your API endpoint
});
function openWidget(orderId) {
  paymentAPI.create({
    order_id: orderId,
  }, {
    // version: 'rc', // test server
    version: 'alpha', // production server
  })
      .then(function(result) {
        if (result.status === 'paid') {
          // Do redirect on a successful payment event
          window.location.href = 'https://example.site/success-payment';
        }
      });
}
</script>
<button
  onclick="openWidget('YOUR ORDER ID')"
>Proceed to pay</button>
```


See demo: [https://pay-example.lunu.io](https://pay-example.lunu.io)



## Attention!

You must modify this script to fit your system, because our script
is extracted from our test environment and there are no orders in it, as we only simulate receiving an order.  
The order ID is generated randomly and amount, token, currency are hardcoded:  
```ruby
def get_my_order_by_id(order_id)

  # Your code should be here.

  # Secret token generated by your engine for this order.
  my_order_secret_token = '3858f62230ac3c915f300c664312c63f'

  # ID generated by your engine for this order.
  my_order_id = rand(9999999999).to_s + '_' + Time.new.to_i.to_s
  {
    :id => my_order_id,
    :amount => 3,
    :token => my_order_secret_token,
    :currency => 'EUR'
  }
end
```
For your system, you will most likely need to use the order IDs generated
by your system in order to track the progress of your orders.  


In order to make our widget easier to integrate with third-party developers,
the widget creation method passes all the necessary parameters directly to the payment creation script:
```js
// ...
// Your params
var params = {
  your_custom_param: 'YOUR CUSTOM PARAM',
  order_id: 'YOUR SHOP ORDER ID',
};
paymentAPI.create(params, {
  version: 'alpha',
});
//...
```

**Server versions specified in your script and in widget options must be the same.**
```js
paymentAPI.create(params, {
  version: 'alpha', // production server
});
```

In app/controllers/lunu_pay_controller.rb:
```ruby
LUNUPAY_ENDPOINT = 'https://alpha.lunu.io/api/v1/payments/' # production server
```


# API credentials

To make new API credentials, You should make order a Widget on this page: https://console.lunu.io/widgets/new

For tests, you can use these data: 
* App ID = `a63127be-6440-9ecd-8baf-c7d08e379dab`
* Api secret = `25615105-7be2-4c25-9b4b-2f50e86e2311`