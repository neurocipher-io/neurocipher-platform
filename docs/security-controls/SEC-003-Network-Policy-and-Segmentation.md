  

id: SEC-003
title: Network Policy and Segmentation
owner: Security Engineering
status: Draft for review
last_reviewed: 2025-11-15

SEC-003 Network Policy and Segmentation

  

  

Neurocipher Data Pipeline • Scope: AWS VPC network layout, segmentation, endpoint policy, and traffic governance for all data-flow paths.

  

  

  

  

1. Objective

  

  

Enforce isolation between ingress, compute, and data tiers. Limit egress, prevent lateral movement, and maintain encrypted paths for all inter-service communication.

  

  

  

  

2. Network topology

  

|   |   |   |
|---|---|---|
|Zone|Purpose|Key resources|
|Public subnets|Entry points|CloudFront, WAF, API Gateway, ALB (public)|
|Private-app subnets|Compute|Lambda ENIs, ECS Fargate tasks, Glue jobs|
|Private-data subnets|Storage|Weaviate cluster, S3 Gateway endpoint, DynamoDB endpoint|
|Management subnet|CI/CD, admin|CodeBuild, CodePipeline, SSM bastion|
|Audit subnet|Logging and guard services|GuardDuty collector, Security Hub, CloudTrail delivery|

  

  

  

  

3. VPC layout

  

  

- CIDR: 10.0.0.0/16  
    

- AZ-A: 10.0.0.0/19 public, 10.0.32.0/19 private-app, 10.0.64.0/19 private-data
- AZ-B: same mirrored for HA

-   
    
- Subnets tagged tier=public|app|data, env=prod|staging.
- Route tables:  
    

- Public → IGW
- Private-app → NAT (for patch fetch only)
- Private-data → no NAT; only VPC endpoints.

-   
    

  

  

  

  

  

4. Connectivity rules

  

  

  

4.1 Ingress

  

  

- Internet → CloudFront (443 only).
- CloudFront → API Gateway private integration via VPC Link.
- No direct inbound from Internet to Lambda, Fargate, or Weaviate.

  

  

  

4.2 East-West

  

  

- Lambda ↔ S3 via Gateway endpoint.
- Fargate ↔ Weaviate via NLB (private).
- ETL ↔ DynamoDB via endpoint.
- CI/CD ↔ ECR via endpoint.
- No cross-AZ peering except defined replication paths.

  

  

  

4.3 Egress

  

  

- NAT Gateway restricted to allowlist domains for package repos (pypi.org, docker.io, amazonlinux).
- VPC FlowLogs + GuardDuty monitor outbound anomalies.
- SCP SCP-DenyInternetEgress denies ec2:CreateNetworkInterface with public IP.

  

  

  

  

  

5. Security Groups

  

|   |   |   |   |
|---|---|---|---|
|SG|Ingress|Egress|Purpose|
|sg-api-gateway|CF CIDR 443|Lambda ENI 443|API Gateway private integration|
|sg-lambda-etl|API GW 443|S3 443, KMS 443, Weaviate 443|ETL function runtime|
|sg-fargate-vector|Lambda 443|Weaviate 443, S3 443|Vector processing|
|sg-weaviate|Fargate 443|none|Vector DB listener only|
|sg-admin-bastion|SSO VPN 443|Private subnets 22/443|SSM tunneled management|

All SGs default-deny inbound/outbound except explicit 443 rules.

  

  

  

  

6. Network ACLs

  

  

- Deny all inbound except 443 and 22 (22 limited to bastion).
- Deny all outbound except 443.
- Explicit DENY for ephemeral ports to prevent reverse shells.

  

  

  

  

  

7. VPC Endpoints

  

|   |   |   |
|---|---|---|
|Service|Type|Policy|
|S3|Gateway|Principal = *, aws:SourceVpce = specific IDs|
|DynamoDB|Gateway|Allow only pipeline roles|
|KMS|Interface|aws:PrincipalTag/app = neurocipher-pipeline|
|Secrets Manager|Interface|same tag restriction|
|STS|Interface|restrict to org accounts|
|Logs / CloudWatch|Interface|read/write allowed for telemetry|

All endpoints have private DNS enabled.

  

  

  

  

8. Zero-Trust and segmentation logic

  

  

- Every inter-service call authenticated via SigV4.
- SGs and IAM tags jointly enforce ABAC: no communication without matching env and app tags.
- Bastion access only through SSM Session Manager; no public SSH.
- Network Access Analyzer runs daily drift checks.
- GuardDuty findings auto-quarantine offending SG rules through Lambda automation.

  

  

  

  

  

9. Encryption in transit

  

  

- TLS 1.2+ enforced on CloudFront, API Gateway, ALB, and Weaviate.
- ACM certificates with auto-renew.
- Private services use ACM Private CA-issued certs distributed via SSM Parameter Store.

  

  

  

  

  

10. Observability

  

  

- VPC Flow Logs to centralized log account.
- CloudWatch Metrics: bytes in/out per SG.
- Network Insights Path used quarterly for validation.
- Macie inspects egress objects.

  

## Acceptance Criteria

- Public, private-app, and private-data subnets are provisioned with the CIDR layout and routing rules described in sections 2 and 3 for all production environments.
- Security groups and NACLs enforce default-deny posture with only the documented 443/22 exceptions, and are verified via automated checks or Network Access Analyzer.
- VPC endpoints for S3, DynamoDB, KMS, Secrets Manager, STS, and CloudWatch are configured with restrictive endpoint policies and private DNS enabled.
- NAT egress is restricted to approved package repositories, and outbound egress anomalies are monitored via Flow Logs, GuardDuty, and Macie as described.
- Network observability (Flow Logs, Network Insights Path, SG metrics) and corresponding alerts are deployed and integrated into central dashboards.

  

11. Residual risk

  

  

- Temporary NAT usage for OS updates—mitigated by limited CIDRs and IAM condition keys.
- Possible DNS exfil—mitigated via Route 53 Resolver query logging and denylist domains.

  

  

  

  

  

12. Compliance mapping

  

|   |   |
|---|---|
|Framework|Controls|
|CIS AWS 1.5|4.1 – 4.4, 5.3|
|NIST 800-53|SC-7, SC-13, SC-23|
|ISO 27001|A.8.20, A.8.23, A.8.26|

  