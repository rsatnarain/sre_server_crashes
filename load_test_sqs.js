import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
  stages: [
    { duration: '15s', target: 2100 }, // Ramp up to 2100 users over 15 seconds
    { duration: '1m', target: 15000 },  // Spike to 15000 users and hold for 1 minute (The 9 AM Herd)
    { duration: '15s', target: 0 },   // Ramp down to 0
  ],
};

export default function () {
  // The SQS Queue URL from your Terraform output
  const url = 'https://sqs.us-east-1.amazonaws.com/135775792334/user-request-queue';

  // SQS SendMessage expects a URL-encoded body with Action and MessageBody
  const payload = 'Action=SendMessage&MessageBody=ThunderingHerdRequest';

  const params = {
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
  };

  // We are now POSTing to the Queue instead of GETting the Server
  http.post(url, payload, params); 
  
  sleep(1);
}