import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 100 }, // Ramp up to 100 users over 30 seconds
    { duration: '1m', target: 500 },  // Spike to 500 users and hold for 1 minute (The 9 AM Herd)
    { duration: '30s', target: 0 },   // Ramp down to 0
  ],
};

export default function () {
  http.get('http://3.86.71.100'); 
  sleep(1);
}