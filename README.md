1. Check/Install ansible and terraform
2. Generate gcp key.json file
3. Update terraform.tfvars with your data and var ansible_user with yout gcp username in stage(ansible/group_vars)
4. terraform init                   (in terraform folder)
5. terraform apply                  (in terraform folder)
6. ansible-playbook setupApache.yml (in ansible folder)