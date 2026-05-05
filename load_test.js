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
  http.get('http://3.86.71.100'); 
  sleep(1);
}