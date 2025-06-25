const axios = require('axios');

const testPaymentIntent = async () => {
  try {
    const response = await axios.post('http://localhost:3000/create-payment-intent', {
      amount: 2000, // $20.00 in cents
      currency: 'usd'
    });

    console.log('Payment Intent created successfully:');
    console.log('Client Secret:', response.data.client_secret);
    console.log('Payment Intent ID:', response.data.payment_intent_id);
  } catch (error) {
    console.error('Error:', error.response?.data || error.message);
  }
};

testPaymentIntent();