# EC2 Firecracker Host Setup (Phase 0 catch-up)

This covers the missing EC2 setup from the early platform phases so you can manually sign in and continue.

## What this gives you

- Launch 1 KVM-capable EC2 host (`i3.metal` default)
- Auto-bootstrap Firecracker + Jailer on first boot
- Locked-down SSH security group (your IP only)
- Optional Elastic IP
- Cleanup script for teardown

## Files

- `user-data-firecracker.sh` — instance bootstrap
- `launch-firecracker-host.ps1` — create security group + launch instance
- `terminate-firecracker-host.ps1` — terminate + cleanup

## Prerequisites

- AWS CLI authenticated (`aws sts get-caller-identity` works)
- Existing VPC + public subnet
- Existing EC2 key pair in target region
- Local SSH private key for that key pair

## 1) Verify login

```powershell
aws sts get-caller-identity
```

## 2) Launch host

Run in PowerShell from repo root:

```powershell
.\infra\ec2\launch-firecracker-host.ps1 `
  -Region us-east-1 `
  -VpcId vpc-xxxxxxxx `
  -SubnetId subnet-xxxxxxxx `
  -KeyName my-keypair `
  -MyIpCidr 203.0.113.10/32 `
  -InstanceType i3.metal `
  -AssociateElasticIp
```

If `i3.metal` is unavailable in your subnet AZ, rerun with `-InstanceType c5.metal`.

## 3) SSH in

```bash
ssh -i <path-to-private-key> ec2-user@<public-ip>
```

## 4) Quick verification on host

```bash
uname -a
ls -l /usr/local/bin/firecracker /usr/local/bin/jailer
ls -l /dev/kvm
cat /etc/firecracker/BOOTSTRAP_DONE
```

## 5) Tear down when done

```powershell
.\infra\ec2\terminate-firecracker-host.ps1 `
  -Region us-east-1 `
  -InstanceId i-xxxxxxxxxxxxxxxxx `
  -SecurityGroupId sg-xxxxxxxxxxxxxxxxx `
  -ElasticIpAllocationId eipalloc-xxxxxxxxxxxxxxxxx
```

## Integration placeholders

The scripts intentionally leave TODO points for other project owners:

- IAM role/profile attachment for runtime AWS access
- ECS registration/capacity provider integration
- snapshot artifact pull + restore workflow
- seccomp policy pipeline integration
