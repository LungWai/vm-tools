gcloud compute firewall-rules create allow-custom-ports \
  --allow=tcp:3000-3010,tcp:5000,tcp:8000-8010 \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --source-ranges=0.0.0.0/0 \
  --description="Allow TCP ports 3000, 5000, and 8000-8010 to all VMs"
