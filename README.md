see https://github.com/xEatos/dashboardduck

We use the ngrok service to provide HTTPS for the local test server:
Create an account and then create the following files in the dev container:
1. Create an account: https://dashboard.ngrok.com/get-started/setup/
2. Run the authtoken command (2nd step of the setup instructions):
   `ngrok config add-authtoken ...`
3. Write the dev domain into the file `/root/ngrok-domain.txt`
  (without any trailing slash)

